import Foundation
import AppKit

/// Turns waiting time into a German lesson focused on the **workplace** — the
/// phrases you need to talk with German colleagues day-to-day. Powers the
/// loading card and a generated "Workplace German" page with flashcards,
/// a quiz, and free resources.
enum GermanCoach {

    struct Lesson { let category: String; let de: String; let en: String }

    /// Workplace-focused dataset (German · English), grouped by scenario.
    static let lessons: [Lesson] = [
        // Greetings & small talk
        .init(category: "Greetings & small talk", de: "Guten Morgen zusammen!", en: "Good morning, everyone!"),
        .init(category: "Greetings & small talk", de: "Hallo, wie geht es dir?", en: "Hi, how are you?"),
        .init(category: "Greetings & small talk", de: "Schönes Wochenende gehabt?", en: "Did you have a nice weekend?"),
        .init(category: "Greetings & small talk", de: "Wie war dein Urlaub?", en: "How was your vacation?"),
        .init(category: "Greetings & small talk", de: "Alles klar bei dir?", en: "Everything good with you?"),
        .init(category: "Greetings & small talk", de: "Schön, dich zu sehen.", en: "Nice to see you."),
        .init(category: "Greetings & small talk", de: "Bis später!", en: "See you later!"),
        .init(category: "Greetings & small talk", de: "Mach's gut!", en: "Take care!"),

        // Arriving, leaving, breaks
        .init(category: "Arriving & breaks", de: "Ich bin heute etwas später dran.", en: "I'm running a bit late today."),
        .init(category: "Arriving & breaks", de: "Ich mache kurz Pause.", en: "I'm taking a short break."),
        .init(category: "Arriving & breaks", de: "Ich gehe in die Mittagspause.", en: "I'm going on my lunch break."),
        .init(category: "Arriving & breaks", de: "Ich bin gleich zurück.", en: "I'll be right back."),
        .init(category: "Arriving & breaks", de: "Ich mache für heute Schluss.", en: "I'm calling it a day."),
        .init(category: "Arriving & breaks", de: "Ich arbeite heute im Homeoffice.", en: "I'm working from home today."),
        .init(category: "Arriving & breaks", de: "Ich bin ab 15 Uhr erreichbar.", en: "I'm available from 3 p.m."),
        .init(category: "Arriving & breaks", de: "Wann ist heute Feierabend?", en: "When do we finish work today?"),

        // Stand-up / daily updates
        .init(category: "Stand-up & updates", de: "Gestern habe ich die Aufgabe abgeschlossen.", en: "Yesterday I finished the task."),
        .init(category: "Stand-up & updates", de: "Heute arbeite ich am Login-Feature.", en: "Today I'm working on the login feature."),
        .init(category: "Stand-up & updates", de: "Ich bin bei diesem Punkt blockiert.", en: "I'm blocked on this point."),
        .init(category: "Stand-up & updates", de: "Es läuft alles nach Plan.", en: "Everything is going to plan."),
        .init(category: "Stand-up & updates", de: "Ich liege gut in der Zeit.", en: "I'm well on schedule."),
        .init(category: "Stand-up & updates", de: "Ich hänge etwas hinterher.", en: "I'm a bit behind."),
        .init(category: "Stand-up & updates", de: "Keine Blocker von meiner Seite.", en: "No blockers on my side."),
        .init(category: "Stand-up & updates", de: "Ich brauche Hilfe bei dieser Aufgabe.", en: "I need help with this task."),

        // Meetings & discussions
        .init(category: "Meetings", de: "Können wir einen Termin vereinbaren?", en: "Can we schedule a meeting?"),
        .init(category: "Meetings", de: "Lass uns das kurz besprechen.", en: "Let's discuss this briefly."),
        .init(category: "Meetings", de: "Ich teile mal meinen Bildschirm.", en: "Let me share my screen."),
        .init(category: "Meetings", de: "Könntest du das kurz erklären?", en: "Could you explain that briefly?"),
        .init(category: "Meetings", de: "Ich habe eine Frage dazu.", en: "I have a question about that."),
        .init(category: "Meetings", de: "Fassen wir das kurz zusammen.", en: "Let's summarize this briefly."),
        .init(category: "Meetings", de: "Wer übernimmt das?", en: "Who will take this on?"),
        .init(category: "Meetings", de: "Lass uns das auf morgen verschieben.", en: "Let's move this to tomorrow."),

        // Asking for help / clarification
        .init(category: "Asking for help", de: "Hast du kurz Zeit?", en: "Do you have a minute?"),
        .init(category: "Asking for help", de: "Kannst du mir dabei helfen?", en: "Can you help me with this?"),
        .init(category: "Asking for help", de: "Ich verstehe das nicht ganz.", en: "I don't fully understand this."),
        .init(category: "Asking for help", de: "Wie meinst du das genau?", en: "What exactly do you mean?"),
        .init(category: "Asking for help", de: "Kannst du das näher erläutern?", en: "Can you elaborate on that?"),
        .init(category: "Asking for help", de: "Könntest du mir ein Beispiel geben?", en: "Could you give me an example?"),
        .init(category: "Asking for help", de: "Wo finde ich das?", en: "Where can I find that?"),
        .init(category: "Asking for help", de: "An wen wende ich mich da am besten?", en: "Who should I best ask about that?"),

        // Opinions / agree / disagree
        .init(category: "Opinions", de: "Da stimme ich dir zu.", en: "I agree with you."),
        .init(category: "Opinions", de: "Das sehe ich genauso.", en: "I see it the same way."),
        .init(category: "Opinions", de: "Da bin ich anderer Meinung.", en: "I disagree there."),
        .init(category: "Opinions", de: "Das ist ein guter Punkt.", en: "That's a good point."),
        .init(category: "Opinions", de: "Können wir einen Kompromiss finden?", en: "Can we find a compromise?"),
        .init(category: "Opinions", de: "Ich schlage vor, dass wir es testen.", en: "I suggest that we test it."),
        .init(category: "Opinions", de: "Aus meiner Sicht ist das sinnvoll.", en: "From my point of view that makes sense."),
        .init(category: "Opinions", de: "Ich bin mir da nicht sicher.", en: "I'm not sure about that."),

        // Deadlines / planning
        .init(category: "Deadlines & planning", de: "Bis wann brauchst du das?", en: "By when do you need this?"),
        .init(category: "Deadlines & planning", de: "Die Frist ist am Freitag.", en: "The deadline is on Friday."),
        .init(category: "Deadlines & planning", de: "Das hat hohe Priorität.", en: "This is high priority."),
        .init(category: "Deadlines & planning", de: "Das können wir später machen.", en: "We can do this later."),
        .init(category: "Deadlines & planning", de: "Ich schaffe das bis morgen.", en: "I'll get this done by tomorrow."),
        .init(category: "Deadlines & planning", de: "Das dauert etwas länger.", en: "This will take a bit longer."),
        .init(category: "Deadlines & planning", de: "Lass uns Prioritäten setzen.", en: "Let's set priorities."),
        .init(category: "Deadlines & planning", de: "Ich kümmere mich darum.", en: "I'll take care of it."),

        // Email & chat
        .init(category: "Email & chat", de: "Ich melde mich später bei dir.", en: "I'll get back to you later."),
        .init(category: "Email & chat", de: "Ich schicke dir die Details per Mail.", en: "I'll send you the details by email."),
        .init(category: "Email & chat", de: "Danke für deine schnelle Antwort.", en: "Thanks for your quick reply."),
        .init(category: "Email & chat", de: "Anbei findest du die Datei.", en: "Please find the file attached."),
        .init(category: "Email & chat", de: "Kurze Rückfrage dazu:", en: "A quick follow-up question on this:"),
        .init(category: "Email & chat", de: "Ich halte dich auf dem Laufenden.", en: "I'll keep you posted."),
        .init(category: "Email & chat", de: "Melde dich, wenn du Fragen hast.", en: "Let me know if you have any questions."),
        .init(category: "Email & chat", de: "Viele Grüße", en: "Best regards"),

        // Problems / mistakes / apologizing
        .init(category: "Problems & apologies", de: "Da ist ein Fehler aufgetreten.", en: "An error occurred."),
        .init(category: "Problems & apologies", de: "Das war mein Fehler, tut mir leid.", en: "That was my mistake, sorry."),
        .init(category: "Problems & apologies", de: "Lass uns eine Lösung finden.", en: "Let's find a solution."),
        .init(category: "Problems & apologies", de: "Das funktioniert bei mir nicht.", en: "This isn't working for me."),
        .init(category: "Problems & apologies", de: "Kannst du das noch mal prüfen?", en: "Can you check this again?"),
        .init(category: "Problems & apologies", de: "Ich kümmere mich sofort darum.", en: "I'll take care of it right away."),
        .init(category: "Problems & apologies", de: "Entschuldige die Verspätung.", en: "Sorry for the delay."),
        .init(category: "Problems & apologies", de: "Kein Problem, das passiert.", en: "No problem, it happens."),

        // Feedback
        .init(category: "Feedback", de: "Kann ich dir kurz Feedback geben?", en: "Can I give you some quick feedback?"),
        .init(category: "Feedback", de: "Das hast du gut gemacht.", en: "You did that well."),
        .init(category: "Feedback", de: "Hier sehe ich noch Verbesserungspotenzial.", en: "I see room for improvement here."),
        .init(category: "Feedback", de: "Danke für dein Feedback.", en: "Thanks for your feedback."),
        .init(category: "Feedback", de: "Was könnte ich besser machen?", en: "What could I do better?"),
        .init(category: "Feedback", de: "Insgesamt sieht das gut aus.", en: "Overall this looks good."),
        .init(category: "Feedback", de: "Lass uns das im Review besprechen.", en: "Let's discuss this in the review."),

        // Calls / video
        .init(category: "Calls & video", de: "Hörst du mich?", en: "Can you hear me?"),
        .init(category: "Calls & video", de: "Du bist auf stumm.", en: "You're on mute."),
        .init(category: "Calls & video", de: "Die Verbindung ist schlecht.", en: "The connection is bad."),
        .init(category: "Calls & video", de: "Kannst du dein Video einschalten?", en: "Can you turn on your video?"),
        .init(category: "Calls & video", de: "Ich rufe dich gleich an.", en: "I'll call you in a moment."),
        .init(category: "Calls & video", de: "Können wir kurz telefonieren?", en: "Can we have a quick call?"),
        .init(category: "Calls & video", de: "Lass uns die Aufnahme starten.", en: "Let's start the recording."),

        // Social: coffee & lunch
        .init(category: "Coffee & lunch", de: "Gehen wir zusammen Mittagessen?", en: "Shall we go to lunch together?"),
        .init(category: "Coffee & lunch", de: "Möchtest du einen Kaffee?", en: "Would you like a coffee?"),
        .init(category: "Coffee & lunch", de: "Hast du Lust auf einen Kaffee?", en: "Do you feel like a coffee?"),
        .init(category: "Coffee & lunch", de: "Lass uns kurz frische Luft schnappen.", en: "Let's get some fresh air."),
        .init(category: "Coffee & lunch", de: "Guten Appetit!", en: "Enjoy your meal!"),
        .init(category: "Coffee & lunch", de: "War nett, mit dir zu reden.", en: "It was nice talking to you."),

        // Onboarding / IT / logistics
        .init(category: "Onboarding & IT", de: "Wo finde ich die Dokumentation?", en: "Where do I find the documentation?"),
        .init(category: "Onboarding & IT", de: "Ich habe keinen Zugriff darauf.", en: "I don't have access to this."),
        .init(category: "Onboarding & IT", de: "Kannst du mir Zugriff geben?", en: "Can you give me access?"),
        .init(category: "Onboarding & IT", de: "Mein Passwort funktioniert nicht.", en: "My password isn't working."),
        .init(category: "Onboarding & IT", de: "An wen wende ich mich bei IT-Problemen?", en: "Who do I contact for IT problems?"),
        .init(category: "Onboarding & IT", de: "Wie funktioniert das hier?", en: "How does this work here?"),
        .init(category: "Onboarding & IT", de: "Wo ist die Teeküche?", en: "Where is the break room / kitchenette?")
    ]

    /// Flat (de, en) list for the loading card.
    static var phrases: [(de: String, en: String)] { lessons.map { ($0.de, $0.en) } }

    /// A persisted cursor so phrases continue where they left off (no repeats
    /// until the whole set has been shown), across loads and app launches.
    private static let cursorKey = "german.phrase.cursor"
    static func nextIndex() -> Int {
        let cursor = UserDefaults.standard.integer(forKey: cursorKey)
        UserDefaults.standard.set(cursor + 1, forKey: cursorKey)
        let count = max(phrases.count, 1)
        return ((cursor % count) + count) % count
    }

    // MARK: - Coach page

    /// Write the workplace-German page (phrases + flashcards + quiz + resources)
    /// to Application Support and open it in the browser.
    static func openResources() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AIThings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("learn-german.html")
        try? coachHTML.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)
    }
}
