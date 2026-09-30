import Foundation

// Reads hoodie_clips.json and emits one Pose per tick (tickRate from the JSON, 12/s).
// Drive it from your render loop: accumulate dt, call tick() each 1/tickRate s,
// then draw the cached frame for the returned Pose. Pause by simply not calling tick().

struct Pose: Hashable {
    enum Head: String, Decodable { case N, L, R }
    var f = 0            // 0 relaxed, 1 reach, 2 pocketed
    var head: Head = .N  // rows < 27 come from this head; matching hair layer
    var o = 0            // torso offset px (+ up), rows < 75
    var s = 0            // upper-hair lag px (+ right), rows < 15
    var b = 0            // blink 0/1/2; patch set chosen by head (N/L/R)
}

struct ClipConfig: Decodable {
    struct PosePatch: Decodable { var f: Int?; var head: Pose.Head?; var o: Int?; var s: Int?; var b: Int? }
    enum Length: Decodable {
        case fixed(Int), range(Int, Int)
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let n = try? c.decode(Int.self) { self = .fixed(n); return }
            struct R: Decodable { let min: Int; let max: Int }
            let r = try c.decode(R.self); self = .range(r.min, r.max)
        }
    }
    struct Step: Decodable {
        let patch: PosePatch; let length: Length
        init(from d: Decoder) throws {
            var c = try d.unkeyedContainer()
            patch = try c.decode(PosePatch.self); length = try c.decode(Length.self)
        }
    }
    struct Schedule: Decodable {
        let glanceEverySec: [Double], glanceAlternateChance: Double, glanceBlinkChance: Double
        let handsInForSec: [Double], handsOutForSec: [Double]
        let blinkEverySec: [Double], doubleBlinkChance: Double
        let startState: String, firstEnterAfterSec: Double, settleAfterHandsSec: Double
    }
    let tickRate: Int
    let clips: [String: [Step]]
    let schedule: Schedule
}

final class IdleScheduler {
    private let cfg: ClipConfig
    private var rng = SystemRandomNumberGenerator()
    private(set) var handsIn: Bool
    private var clip: [ClipConfig.PosePatch] = [], clipName = "idle", ci = 0
    private var glanceT: Double, handsT: Double, blinkT: Double
    private var lastLeft = Bool.random()

    init(config: ClipConfig) {
        cfg = config
        handsIn = config.schedule.startState == "in"
        glanceT = 0; handsT = config.schedule.firstEnterAfterSec; blinkT = 0
        glanceT = rand(config.schedule.glanceEverySec); blinkT = rand(config.schedule.blinkEverySec)
    }

    private func rand(_ r: [Double]) -> Double { r[0] == r[1] ? r[0] : Double.random(in: r[0]...r[1], using: &rng) }

    private func play(_ name: String) {
        guard let steps = cfg.clips[name] else { return }
        clip = steps.flatMap { step -> [ClipConfig.PosePatch] in
            let n: Int
            switch step.length { case .fixed(let k): n = k; case .range(let a, let b): n = Int.random(in: a...b, using: &rng) }
            return Array(repeating: step.patch, count: n)
        }
        ci = 0; clipName = name
    }

    func tick() -> Pose {
        let s = cfg.schedule, dt = 1.0 / Double(cfg.tickRate)
        glanceT -= dt; handsT -= dt; blinkT -= dt

        if !clip.isEmpty && ci >= clip.count {            // clip finished
            if clipName == "enter" { handsIn = true;  handsT = rand(s.handsInForSec) }
            if clipName == "exit"  { handsIn = false; handsT = rand(s.handsOutForSec) }
            if clipName == "enter" || clipName == "exit" { glanceT = max(glanceT, s.settleAfterHandsSec) }
            clip = []; clipName = "idle"
        }
        if clip.isEmpty {                                  // idle: hands > glance > blink
            if handsT <= 0 { play(handsIn ? "exit" : "enter") }
            else if glanceT <= 0 {
                let alternate = Double.random(in: 0..<1, using: &rng) < s.glanceAlternateChance
                let left = alternate ? !lastLeft : lastLeft
                lastLeft = left
                let blink = Double.random(in: 0..<1, using: &rng) < s.glanceBlinkChance
                play((left ? "glanceLeft" : "glanceRight") + (blink ? "Blink" : "")); glanceT = rand(s.glanceEverySec)
            } else if blinkT <= 0 {
                play(Double.random(in: 0..<1, using: &rng) < s.doubleBlinkChance ? "doubleBlink" : "blink")
                blinkT = rand(s.blinkEverySec)
            }
        }
        var p = Pose(f: handsIn ? 2 : 0)
        if ci < clip.count {
            let q = clip[ci]; ci += 1
            if let v = q.f { p.f = v }; if let v = q.head { p.head = v }
            if let v = q.o { p.o = v }; if let v = q.s { p.s = v }; if let v = q.b { p.b = v }
        }
        return p
    }
}

// Usage:
// let cfg = try JSONDecoder().decode(ClipConfig.self, from: Data(contentsOf: url))
// let scheduler = IdleScheduler(config: cfg)
// every 1/12 s:  let pose = scheduler.tick();  sprite.texture = cache.texture(for: pose, hair:, skin:)
