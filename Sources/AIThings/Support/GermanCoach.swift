import Foundation
import AppKit

/// Turns waiting time into a tiny German lesson: a rotating set of useful
/// sentences, plus a generated HTML page of free resources (DW and friends).
enum GermanCoach {

    /// A large, varied set of useful sentences (German · English) so the
    /// loading lesson rarely repeats. Grouped loosely by theme.
    static let phrases: [(de: String, en: String)] = [
        // Greetings & basics
        ("Guten Morgen, wie hast du geschlafen?", "Good morning, how did you sleep?"),
        ("Guten Tag, schön dich zu sehen.", "Good day, nice to see you."),
        ("Guten Abend, wie war dein Tag?", "Good evening, how was your day?"),
        ("Bis bald, mach's gut!", "See you soon, take care!"),
        ("Wir sehen uns morgen.", "See you tomorrow."),
        ("Wie geht es dir heute?", "How are you today?"),
        ("Mir geht es gut, danke.", "I'm doing well, thanks."),
        ("Und dir, wie läuft's?", "And you, how's it going?"),
        ("Lange nicht gesehen!", "Long time no see!"),
        ("Willkommen, schön dass du da bist.", "Welcome, glad you're here."),

        // Politeness
        ("Könntest du mir bitte helfen?", "Could you please help me?"),
        ("Vielen Dank für deine Hilfe.", "Thank you very much for your help."),
        ("Entschuldigung, ich habe eine Frage.", "Excuse me, I have a question."),
        ("Das ist sehr nett von dir.", "That's very kind of you."),
        ("Gern geschehen.", "You're welcome."),
        ("Kein Problem, mach dir keine Sorgen.", "No problem, don't worry."),
        ("Darf ich dich etwas fragen?", "May I ask you something?"),
        ("Tut mir leid, das war mein Fehler.", "I'm sorry, that was my mistake."),

        // Learning the language
        ("Wie sagt man das auf Deutsch?", "How do you say that in German?"),
        ("Was bedeutet dieses Wort?", "What does this word mean?"),
        ("Kannst du das bitte wiederholen?", "Can you repeat that, please?"),
        ("Kannst du langsamer sprechen?", "Can you speak more slowly?"),
        ("Ich lerne jeden Tag ein bisschen.", "I learn a little every day."),
        ("Ich verstehe das noch nicht ganz.", "I don't quite understand it yet."),
        ("Wie schreibt man das?", "How do you spell that?"),
        ("Ich übe mein Deutsch.", "I'm practicing my German."),
        ("Sprichst du Englisch?", "Do you speak English?"),
        ("Ich spreche ein bisschen Deutsch.", "I speak a little German."),

        // Time & dates
        ("Wie spät ist es?", "What time is it?"),
        ("Es ist Viertel nach drei.", "It's quarter past three."),
        ("Wir treffen uns um acht Uhr.", "We're meeting at eight o'clock."),
        ("Heute ist Montag.", "Today is Monday."),
        ("Am Wochenende habe ich frei.", "I'm off on the weekend."),
        ("Ich bin in fünf Minuten da.", "I'll be there in five minutes."),
        ("Es ist noch früh.", "It's still early."),
        ("Wir haben keine Zeit zu verlieren.", "We have no time to lose."),

        // Daily life
        ("Ich muss noch einkaufen gehen.", "I still need to go shopping."),
        ("Das Wetter ist heute schön.", "The weather is nice today."),
        ("Es regnet, nimm einen Schirm mit.", "It's raining, take an umbrella."),
        ("Ich bin müde, ich gehe schlafen.", "I'm tired, I'm going to sleep."),
        ("Hast du schon gegessen?", "Have you eaten yet?"),
        ("Ich habe Hunger.", "I'm hungry."),
        ("Ich habe Durst.", "I'm thirsty."),
        ("Mach das Licht bitte aus.", "Turn off the light, please."),

        // Food & drink
        ("Ich hätte gerne einen Kaffee.", "I would like a coffee."),
        ("Was möchtest du trinken?", "What would you like to drink?"),
        ("Die Rechnung, bitte.", "The bill, please."),
        ("Das schmeckt richtig gut.", "That tastes really good."),
        ("Ich nehme das Gleiche.", "I'll have the same."),
        ("Zum Wohl!", "Cheers!"),
        ("Guten Appetit!", "Enjoy your meal!"),
        ("Ich bin satt, danke.", "I'm full, thank you."),

        // Travel & directions
        ("Wo ist der Bahnhof?", "Where is the train station?"),
        ("Wie komme ich zum Zentrum?", "How do I get to the center?"),
        ("Geh geradeaus und dann links.", "Go straight ahead and then left."),
        ("Ist es weit von hier?", "Is it far from here?"),
        ("Ich habe mich verlaufen.", "I've gotten lost."),
        ("Welcher Zug fährt nach Berlin?", "Which train goes to Berlin?"),
        ("Einmal nach Hamburg, bitte.", "One ticket to Hamburg, please."),
        ("Wann fährt der nächste Bus?", "When does the next bus leave?"),

        // Shopping
        ("Wie viel kostet das?", "How much does that cost?"),
        ("Das ist zu teuer.", "That's too expensive."),
        ("Haben Sie das in einer anderen Größe?", "Do you have this in another size?"),
        ("Ich schaue mich nur um.", "I'm just looking around."),
        ("Kann ich mit Karte bezahlen?", "Can I pay by card?"),
        ("Ich nehme es.", "I'll take it."),

        // Work, study & coding
        ("Heute ist ein guter Tag zum Programmieren.", "Today is a good day for coding."),
        ("Ich arbeite an einem neuen Projekt.", "I'm working on a new project."),
        ("Der Code funktioniert jetzt.", "The code works now."),
        ("Ich muss diesen Fehler beheben.", "I need to fix this bug."),
        ("Lass uns das Problem lösen.", "Let's solve the problem."),
        ("Wir sind fast fertig.", "We're almost done."),
        ("Ich habe eine Idee.", "I have an idea."),
        ("Das ergibt Sinn.", "That makes sense."),
        ("Können wir das später besprechen?", "Can we discuss this later?"),
        ("Ich kümmere mich darum.", "I'll take care of it."),

        // Feelings & opinions
        ("Ich freue mich darauf.", "I'm looking forward to it."),
        ("Das gefällt mir sehr.", "I like that a lot."),
        ("Ich bin stolz auf dich.", "I'm proud of you."),
        ("Das ist eine gute Idee.", "That's a good idea."),
        ("Ich bin mir nicht sicher.", "I'm not sure."),
        ("Das finde ich interessant.", "I find that interesting."),
        ("Mach dir keine Sorgen.", "Don't worry."),
        ("Ich verstehe, was du meinst.", "I understand what you mean."),

        // Encouragement & getting things done
        ("Lass uns anfangen.", "Let's get started."),
        ("Schritt für Schritt.", "Step by step."),
        ("Bleib dran, du schaffst das!", "Keep at it, you can do it!"),
        ("Ich gebe nicht auf.", "I won't give up."),
        ("Das kriegen wir hin.", "We'll manage that."),
        ("Immer mit der Ruhe.", "Take it easy."),
        ("Noch einen Augenblick, bitte.", "Just a moment, please."),
        ("Es funktioniert!", "It works!"),

        // Idioms & proverbs
        ("Übung macht den Meister.", "Practice makes perfect."),
        ("Aller Anfang ist schwer.", "Every beginning is hard."),
        ("Ich verstehe nur Bahnhof.", "I don't understand a thing. (idiom)"),
        ("Wo ein Wille ist, ist auch ein Weg.", "Where there's a will, there's a way."),
        ("Geduld ist eine Tugend.", "Patience is a virtue."),
        ("Fehler sind zum Lernen da.", "Mistakes are there to learn from."),
        ("Morgenstund hat Gold im Mund.", "The early bird catches the worm. (idiom)"),
        ("Ende gut, alles gut.", "All's well that ends well."),
        ("Das ist mir Wurst.", "I don't care. (idiom)"),
        ("Da liegt der Hund begraben.", "That's the crux of the matter. (idiom)"),
        ("Daumen drücken!", "Fingers crossed!"),
        ("Es ist noch kein Meister vom Himmel gefallen.", "No one is born a master.")
    ]

    /// A persisted cursor so phrases continue where they left off (no repeats
    /// until the whole set has been shown), across loads and app launches.
    private static let cursorKey = "german.phrase.cursor"
    static func nextIndex() -> Int {
        let cursor = UserDefaults.standard.integer(forKey: cursorKey)
        UserDefaults.standard.set(cursor + 1, forKey: cursorKey)
        return ((cursor % phrases.count) + phrases.count) % phrases.count
    }

    /// Write the resources page to Application Support and open it in the browser.
    static func openResources() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AIThings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("learn-german.html")
        try? resourcesHTML.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)
    }

    /// A clean, brand-styled page listing free German-learning resources.
    static let resourcesHTML = """
    <!doctype html><html lang="en"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Learn German — Free Resources</title>
    <style>
      :root{color-scheme:dark}
      body{font:16px/1.6 -apple-system,system-ui,sans-serif;background:#0b1620;color:#e9f0f7;margin:0;padding:48px 24px;max-width:880px;margin-inline:auto}
      header{display:flex;align-items:center;gap:14px;margin-bottom:6px}
      .mark{width:40px;height:40px;border:3px solid #6bb0f0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:800;color:#6bb0f0;font-size:13px}
      h1{margin:0;font-weight:800}
      .sub{color:#8597a9;margin:0 0 28px}
      h2{color:#6bb0f0;margin-top:34px;font-size:18px}
      .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}
      a.card{display:block;text-decoration:none;background:#111e2b;border:1px solid rgba(255,255,255,.08);border-radius:12px;padding:16px 18px;color:#e9f0f7;transition:.15s}
      a.card:hover{border-color:#6bb0f0;transform:translateY(-2px)}
      a.card b{color:#e9f0f7}
      a.card span{display:block;color:#8597a9;font-size:13px;margin-top:4px}
      footer{margin-top:40px;color:#5d6b7c;font-size:13px}
      .tag{display:inline-block;font-size:11px;color:#0b1620;background:#6bb0f0;border-radius:6px;padding:1px 7px;margin-left:6px;vertical-align:middle}
    </style></head><body>
      <header><div class="mark">AI</div><h1>Learn German — Free Resources</h1></header>
      <p class="sub">A curated list of free, high-quality ways to learn German. Curated by AI-Things.</p>

      <h2>Deutsche Welle (DW) <span class="tag">free · top pick</span></h2>
      <div class="grid">
        <a class="card" href="https://learngerman.dw.com/en/overview"><b>DW Learn German</b><span>Full A1–C1 courses, free.</span></a>
        <a class="card" href="https://learngerman.dw.com/en/nicos-weg/c-36519789"><b>Nicos Weg</b><span>Story-based A1→B1 video course.</span></a>
        <a class="card" href="https://learngerman.dw.com/en/beginners/c-36519797"><b>DW Vocabulary Trainer</b><span>Themed words with audio.</span></a>
        <a class="card" href="https://www.dw.com/de/deutsch-lernen/nachrichten/s-8030"><b>Langsam gesprochene Nachrichten</b><span>News read slowly, with transcripts.</span></a>
        <a class="card" href="https://learngerman.dw.com/en/top-thema/s-13889957"><b>Top-Thema</b><span>Short articles + audio for B1.</span></a>
      </div>

      <h2>Courses &amp; institutes</h2>
      <div class="grid">
        <a class="card" href="https://www.goethe.de/en/spr/ueb.html"><b>Goethe-Institut — Free practice</b><span>Official exercises &amp; community.</span></a>
        <a class="card" href="https://www.deutschakademie.de/online-deutschkurs/"><b>DeutschAkademie</b><span>20,000+ free grammar exercises.</span></a>
        <a class="card" href="https://www.vhs-lernportal.de/wws/9.php#/wws/deutsch.php"><b>VHS-Lernportal</b><span>Free A1–B2 courses (gov-backed).</span></a>
      </div>

      <h2>Listening &amp; reading</h2>
      <div class="grid">
        <a class="card" href="https://www.nachrichtenleicht.de/"><b>Nachrichtenleicht</b><span>News in simple German + audio.</span></a>
        <a class="card" href="https://www.lingua.com/german/reading/"><b>Lingua.com</b><span>Free graded reading texts + quizzes.</span></a>
        <a class="card" href="https://tatoeba.org/en/sentences/show_all_in/deu/eng"><b>Tatoeba</b><span>Example sentences with translations.</span></a>
      </div>

      <h2>YouTube</h2>
      <div class="grid">
        <a class="card" href="https://www.youtube.com/@EasyGerman"><b>Easy German</b><span>Real street interviews, subtitled.</span></a>
        <a class="card" href="https://www.youtube.com/@LearnGermanwithAnja"><b>Learn German with Anja</b><span>Energetic beginner lessons.</span></a>
        <a class="card" href="https://www.youtube.com/@deutschmitmarija"><b>Deutsch mit Marija</b><span>Clear grammar explanations.</span></a>
      </div>

      <h2>Grammar &amp; dictionaries</h2>
      <div class="grid">
        <a class="card" href="https://deutsch.lingolia.com/en/"><b>Lingolia German</b><span>Grammar explained + exercises.</span></a>
        <a class="card" href="https://www.dict.cc/"><b>dict.cc</b><span>Community dictionary with audio.</span></a>
        <a class="card" href="https://dict.leo.org/german-english/"><b>LEO</b><span>Dictionary + forum.</span></a>
        <a class="card" href="https://context.reverso.net/translation/german-english/"><b>Reverso Context</b><span>Words shown in real sentences.</span></a>
      </div>

      <h2>Practice apps (free tiers)</h2>
      <div class="grid">
        <a class="card" href="https://apps.ankiweb.net/"><b>Anki</b><span>Spaced-repetition flashcards.</span></a>
        <a class="card" href="https://www.tandem.net/"><b>Tandem</b><span>Chat with native speakers.</span></a>
        <a class="card" href="https://seedlang.com/"><b>Seedlang</b><span>Video flashcards from Easy German.</span></a>
      </div>

      <footer>Tip: 10 focused minutes a day beats an hour once a week. Viel Erfolg! 🇩🇪</footer>
    </body></html>
    """
}
