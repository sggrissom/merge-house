import Foundation
import QuartzCore
import SpriteKit

/// A noise the game makes, and the file it makes it with.
///
/// The event half of the same bargain the rest of the prototype runs on. An
/// event knows *what is happening* — two things met, something was put on, you
/// went next door — and nothing about what met or who put it on. What that
/// particular thing sounds like is the thing's business, in `ItemDefinition.sound`.
///
/// Each case names the file it wants, so the recording list is this enum rather
/// than a document that goes stale:
///
/// | File | When it plays |
/// | --- | --- |
/// | `merge` | Two things merge. Pitched up by how far up its chain the result is. |
/// | `top-out` | That merge finished a chain. A fanfare, after the pop. |
/// | `mix` | Two *different* things that go together are put together. |
/// | `pick-up` | Something is lifted off the shelf, the floor or the character. |
/// | `put-down` | It is let go again. |
/// | `wear` | It goes on the character instead. |
/// | `door` | You walk into another room. |
/// | `trash` | Something is thrown away. |
///
/// Any audio format Core Audio reads will do — see `Sounds.fileExtensions` — and
/// none of them existing is the normal state, not an error.
enum SoundEvent: String, CaseIterable {
    case merge
    case topOut = "top-out"
    case mix
    case pickUp = "pick-up"
    case putDown = "put-down"
    case wear
    case door
    case trash

    /// The shared file for this event: what plays when whatever is making the
    /// noise has nothing to say about how it should sound.
    var fileName: String { rawValue }

    /// What it should sound like, for whoever ends up recording it.
    var note: String {
        switch self {
        case .merge: return "a rising pop"
        case .topOut: return "a fanfare"
        case .mix: return "a squelch and a sprinkle"
        case .pickUp: return "a soft tick"
        case .putDown: return "a thud"
        case .wear: return "a little sparkle"
        case .door: return "a door"
        case .trash: return "a crumple"
        }
    }
}

/// Every noise the game makes, and the one place that decides whether it makes
/// any at all.
///
/// Built to the same rule the artwork is: **a missing file is a normal state,
/// not an error.** A sound with no file behind it is silence, exactly as an item
/// with no drawing behind it is a labeled box, and the whole game is playable
/// with not one audio file in the bundle — which is what it has today.
///
/// Where the noises themselves eventually come from is deliberately not decided
/// here. `resolve` is the single door every sound comes through, the way
/// `Artwork.named` is for every drawing, so recorded files landing in the bundle
/// and a synthesiser standing in for the ones that have not been recorded are
/// the same change in one function rather than a change at seven call sites.
enum Sounds {

    // MARK: - Muting

    /// Whether the game is silent. **The first thing a parent wants at bedtime**,
    /// so it is a real setting rather than a per-session accident.
    ///
    /// Kept in `UserDefaults` and not in the save, unlike everything else the
    /// game remembers. A save holds *the things the child made*; muting is not
    /// one of them, and a parent who silences the game at bedtime means the
    /// device rather than the particular shelf of bows that happened to be open.
    /// The batched writes that make `UserDefaults` the wrong home for a save are
    /// no loss here: the worst a crash can cost is one flip of a switch.
    static var isMuted: Bool = UserDefaults.standard.bool(forKey: muteKey) {
        didSet {
            guard isMuted != oldValue else { return }
            UserDefaults.standard.set(isMuted, forKey: muteKey)
        }
    }

    private static let muteKey = "merge-house.muted"

    // MARK: - Playing

    /// Makes a noise, if there is a file to make it with and the game is not muted.
    ///
    /// - Parameters:
    ///   - event: what is happening.
    ///   - voice: what the thing it is happening to sounds like, from
    ///     `ItemDefinition.sound`. `nil` — no opinion — is the common answer and
    ///     gets the event's shared file.
    ///   - pitch: playback rate, which is how a Crown comes out grander than a
    ///     Bow off one recording. `1` is the file as it was recorded.
    ///   - delay: how long to wait first, so a fanfare can land behind its pop.
    ///   - scene: the scene to play through. Optional so a call site does not
    ///     have to prove it is still in a scene before it can make a noise.
    static func play(_ event: SoundEvent,
                     voice: String? = nil,
                     pitch: CGFloat = 1,
                     after delay: TimeInterval = 0,
                     in scene: SKScene?) {
        guard !isMuted, let scene = scene else { return }
        guard let url = resolve(event, voice: voice) else { return }
        guard allowRepeat(of: event) else { return }

        let fire = SKAction.run { [weak scene] in
            // Checked again on the way out as well as on the way in: a fanfare
            // asked for a moment ago should not still arrive after the mute.
            guard let scene = scene, !isMuted else { return }
            Sounds.start(url, pitch: pitch, in: scene)
        }
        scene.run(delay > 0 ? SKAction.sequence([.wait(forDuration: delay), fire]) : fire)
    }

    /// The playback rate for something `level` steps up a merge chain, counting
    /// the bottom of the chain as 1. A minor third per level, so the top of a
    /// four-long chain comes out most of an octave above the bottom of it.
    ///
    /// Rate rather than a recording per level, because the alternative is four
    /// files per chain. It shortens the noise as it raises it, which is right for
    /// a pop and would be wrong for a fanfare — so a chain that wants a grander
    /// top rather than a higher one gets there by giving its top item a `sound`
    /// of its own, which already falls back to this if the file is not there.
    static func pitch(forLevel level: Int) -> CGFloat {
        CGFloat(pow(2.0, Double(max(1, level) - 1) * 0.25))
    }

    // MARK: - Finding the file

    /// The formats a noise may arrive in. Listed rather than guessed at, and in
    /// this order: `caf` and `wav` decode without unpacking, which for a sound
    /// that has to land the instant a finger lifts is the difference worth having.
    static let fileExtensions = ["caf", "wav", "aiff", "m4a", "mp3"]

    /// The file for one event on one thing, or `nil` for silence.
    ///
    /// Three answers in order, and the same shape the artwork rule has: the
    /// thing's own noise, the event's shared noise, then nothing.
    static func resolve(_ event: SoundEvent, voice: String?) -> URL? {
        let names = candidates(for: event, voice: voice)
        for name in names {
            if let url = url(named: name) { return url }
        }
        reportMissing(names)
        return nil
    }

    /// What would be played for this event on this thing, best first.
    ///
    /// A voice is a prefix rather than a whole filename so that one word in the
    /// catalog covers every noise a thing can make: `sound: "teddy"` asks for
    /// `teddy-merge`, `teddy-put-down` and `teddy-pick-up` without the Teddy
    /// having to list them, and each falls back on its own. So recording a soft
    /// thud for teddies and nothing else is a complete, sensible thing to do.
    static func candidates(for event: SoundEvent, voice: String?) -> [String] {
        guard let voice = voice, !voice.isEmpty else { return [event.fileName] }
        return ["\(voice)-\(event.fileName)", event.fileName]
    }

    /// The file with this name in whatever format it happens to be in, or `nil`
    /// if there is no such file — which for every name in the game today is the
    /// answer, and is not an error.
    ///
    /// Guarded rather than trusted, because `SKAction.playSoundFileNamed` traps
    /// on a file that is not there rather than shrugging the way `UIImage(named:)`
    /// does. Everything downstream of here is holding a URL that was found.
    ///
    /// Cached, misses included, so a name nothing answers to does not send every
    /// pop back to the bundle looking for it.
    static func url(named name: String) -> URL? {
        if let known = cache[name] { return known }
        var found: URL?
        for fileExtension in fileExtensions where found == nil {
            found = Bundle.main.url(forResource: name, withExtension: fileExtension)
        }
        cache[name] = found
        return found
    }

    private static var cache: [String: URL?] = [:]

    // MARK: - Making the noise

    /// Two ways to play one file, because pitching is not free.
    ///
    /// `playSoundFileNamed` is the cheap path — SpriteKit keeps the decoded
    /// buffer and fires it with no node to build — but it plays a file exactly as
    /// it was recorded. Anything that wants a rate needs an audio node of its
    /// own, so it gets one, and throws it away when it has finished.
    private static func start(_ url: URL, pitch: CGFloat, in scene: SKScene) {
        guard pitch != 1 else {
            scene.run(.playSoundFileNamed(url.lastPathComponent, waitForCompletion: false))
            return
        }

        let player = SKAudioNode(url: url)
        player.autoplayLooped = false
        player.isPositional = false
        scene.addChild(player)
        player.run(.sequence([
            .changePlaybackRate(to: Float(pitch), duration: 0),
            .play(),
            // Long enough for any noise this game makes, and the node is doing
            // nothing but existing until then.
            .wait(forDuration: 4),
            .removeFromParent(),
        ]))
    }

    /// Whether this event has waited long enough since the last one like it.
    ///
    /// Merge All merges up to two hundred pairs in a single frame, and two
    /// hundred pops at once is not two hundred merges — it is a bang. So the
    /// same event twice in the same instant is one noise, which is what a
    /// cascade should sound like anyway. Different events are not collapsed
    /// into each other, so the fanfare at the end of that cascade still lands.
    private static func allowRepeat(of event: SoundEvent) -> Bool {
        let now = CACurrentMediaTime()
        if let last = lastPlayed[event], now - last < repeatGap { return false }
        lastPlayed[event] = now
        return true
    }

    private static let repeatGap: TimeInterval = 0.05
    private static var lastPlayed: [SoundEvent: TimeInterval] = [:]

    // MARK: - What it is waiting for

    /// Says once, in a debug build, which file a noise would have used.
    ///
    /// The audible half of this feature is silence until somebody records
    /// something, so this is the only way to see that the wiring works at all —
    /// and it is the same promise the drawings make, that a missing file names
    /// itself rather than failing quietly. Once per name: a pop asking for the
    /// same two files on every merge would drown the log it is meant to be
    /// readable in.
    private static func reportMissing(_ names: [String]) {
        #if DEBUG
        guard let wanted = names.first, !reported.contains(wanted) else { return }
        reported.insert(wanted)
        let list = names.joined(separator: " or ")
        print("Sound: silent — needs \(list) as \(fileExtensions.joined(separator: "/"))")
        #endif
    }

    #if DEBUG
    private static var reported: Set<String> = []
    #endif
}

extension SKScene {
    /// Makes a noise from inside a scene. The scene is what plays sounds, so
    /// this is where every call site in the game says so.
    func playSound(_ event: SoundEvent,
                   voice: String? = nil,
                   pitch: CGFloat = 1,
                   after delay: TimeInterval = 0) {
        Sounds.play(event, voice: voice, pitch: pitch, after: delay, in: self)
    }
}
