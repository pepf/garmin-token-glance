import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

//! Turns the snapshot into a headline and one casual line of advice.
module Coach {

    //! A new phrasing every half hour, so it changes between looks but not
    //! between redraws.
    const ROTATE_SECONDS = 1800;

    //! [headline, message]; null if the snapshot lacks one of the windows.
    function advice(s as Dictionary) as [String, String] or Null {
        var h5 = Usage.percent(s, "h5", "r5");
        var d7 = Usage.percent(s, "d7", "r7");
        if (h5 == null || d7 == null || !(s["r5"] instanceof Number) || !(s["r7"] instanceof Number)) {
            return null;
        }

        var left5 = Usage.secondsLeft(s, "r5");
        var left7 = Usage.secondsLeft(s, "r7");
        var state = pick(h5, d7, left5, left7);
        var phrases = state[1];
        var text = phrases[(Time.now().value() / ROTATE_SECONDS) % phrases.size()];
        return [state[0], Lang.format(text, [
            left5 != null ? Usage.duration(left5) : "",
            left7 != null ? Usage.duration(left7) : "",
            h5,
            d7,
            Usage.duration(secondsToEmpty(h5, left5, Usage.FIVE_HOURS)),
            Usage.duration(secondsToEmpty(d7, left7, Usage.SEVEN_DAYS))
        ])];
    }

    //! Seconds of the window that have passed. No reset time ahead means a
    //! new window that has not started.
    function elapsed(left as Number or Null, window as Number) as Number {
        return left != null && left < window ? window - left : 0;
    }

    //! When the window hits 100% if usage continues at its average rate.
    function secondsToEmpty(pct as Number, left as Number or Null, window as Number) as Number {
        return pct > 0 ? elapsed(left, window) * (100 - pct) / pct : 0;
    }

    //! The first match wins, so the most urgent states come first. Phrases can
    //! use $1$ time to 5h reset, $2$ time to 7d reset, $3$ 5h percent, $4$ 7d
    //! percent, and where that window is over pace $5$ / $6$ time until it is
    //! used up at the current rate. "Pace" is the tick on the bar.
    function pick(h5 as Number, d7 as Number, left5 as Number or Null, left7 as Number or Null) as [String, Array<String>] {
        var pace5 = elapsed(left5, Usage.FIVE_HOURS) * 100 / Usage.FIVE_HOURS;
        var pace7 = elapsed(left7, Usage.SEVEN_DAYS) * 100 / Usage.SEVEN_DAYS;
        // Not over pace while there is little use: the first minutes say nothing.
        var over5 = h5 >= 20 && h5 > pace5 + 8;
        var over7 = d7 >= 10 && d7 > pace7 + 5;
        var on5 = h5 >= 10 && h5 >= pace5 - 8;
        var on7 = d7 >= 10 && d7 >= pace7 - 8;
        var lastDay = left7 != null && left7 < 86400;

        // 7-day limit used up
        if (d7 >= 100) {
            if (lastDay) {
                return ["Almost back", [
                    "All gone, but only $2$ to go. Plan your comeback!",
                    "$2$ until a brand new week. Rest up, champ.",
                    "Spent it all with $2$ to go. Honestly? Great timing."
                ]];
            }
            if (pace7 < 50) {
                return ["Oh boy", [
                    "A whole week in half the time. Legendary. See you in $2$!",
                    "100% before halftime! Hand-typing for $2$.",
                    "$2$ without tokens. Learn guitar? Call your mom?"
                ]];
            }
            return ["Week is done", [
                "Every last token, used! Hand-typing for $2$.",
                "All out for $2$. Time to read those bookmarks.",
                "Tank empty, head full. Jot it down, $2$ to go."
            ]];
        }

        // 5-hour limit used up
        if (h5 >= 100) {
            if (left5 != null && left5 <= 45 * 60) {
                return ["Break time", [
                    "$1$ to go. Take a long walk, come back as a new person!",
                    "$1$ left: enough for proper coffee and some sunlight.",
                    "Only $1$. Stretch, hydrate, dream up your next prompt."
                ]];
            }
            var hour = System.getClockTime().hour;
            if (hour >= 22 || hour < 6) {
                return ["Bedtime", [
                    "Tokens are out, and so should you be. Sleep tight!",
                    "Empty tank, late hour. The universe says: go to bed.",
                    "It all resets while you sleep. Best deploy of the day."
                ]];
            }
            if (d7 >= 85) {
                return ["Easy, tiger", [
                    "5h is empty, week at $4$%. Make the next round count!",
                    "Both tanks run dry. $1$ off might do you good."
                ]];
            }
            if (pace5 < 50) {
                return ["Speedrun!", [
                    "5 hours, gone in a flash. $1$ to go: workout time!",
                    "New record? Go outside, back in $1$.",
                    "That was quick! $1$ is enough for a run AND a shower."
                ]];
            }
            return ["All used up", [
                "Well spent! Back in $1$. Go touch some grass.",
                "Refill in $1$. Time to admire what you built.",
                "Take $1$ off. Lunch? Nap? Both? You've earned it."
            ]];
        }

        // Close to a limit
        if (h5 >= 85 && d7 >= 85) {
            return ["On fumes", [
                "5h $3$%, week $4$%. Only the important prompts now!",
                "Both nearly full. Finish that one thing, then close the lid.",
                "Living on the edge, twice. Wrap up and commit your work!"
            ]];
        }
        if (d7 >= 85) {
            if (lastDay) {
                return ["Home stretch", [
                    "$4$%, $2$ to go. Beautifully managed, bring it home!",
                    "Nearly empty, nearly reset. That's what we call a full week."
                ]];
            }
            if (pace7 < 50) {
                return ["Whoa there", [
                    "$4$% before halftime! Save some for the second half.",
                    "Big start! Maybe let the small models play for a while?"
                ]];
            }
            return ["Ration mode", [
                "$4$% used, $2$ to go. Choose your prompts wisely!",
                "Nibble, don't feast: it has to last another $2$.",
                "Nearly through the week. Small bites and you'll make it."
            ]];
        }
        if (h5 >= 85) {
            if (left5 != null && left5 <= 30 * 60) {
                return ["Photo finish", [
                    "$3$% and $1$ to go. Textbook timing, keep rolling!",
                    "Fresh tokens in $1$. You can almost smell them."
                ]];
            }
            if (d7 < 40 && !over7) {
                return ["Short sprint", [
                    "5h nearly gone, week wide open. Breathe, then go again!",
                    "Hot now, cool for the week. A little break costs nothing.",
                    "Intense! Only $4$% of your week though, so no stress."
                ]];
            }
            return ["Nearly there", [
                "$3$% used. Wrap up this thought, then stretch those legs.",
                "Last few sips of this round. Commit before you run dry!",
                "Close to the limit. Is it snack o'clock already?"
            ]];
        }

        // Ahead of pace
        if (over5 && over7) {
            return ["Full throttle", [
                "Ahead on both! 5h dry in $5$, week in $6$.",
                "You're flying today. Maybe glide a little?",
                "Pedal to the metal! At this rate you get a break in $5$."
            ]];
        }
        if (over7) {
            if (d7 > pace7 + 20) {
                return ["Slow it down", [
                    "Way ahead! At this rate the week's done in $6$.",
                    "The week is a marathon and you're sprinting. Ease up!",
                    "Fancy a slow day? Your weekly budget sure does."
                ]];
            }
            return ["A bit hot", [
                "Slightly ahead for the week. One long lunch fixes that.",
                "The week's running a tad fast. Stroll, don't sprint.",
                "$4$% used, a tad over target. Nothing a walk can't fix."
            ]];
        }
        if (over5) {
            if (d7 < pace7 - 15) {
                return ["Go for it", [
                    "Busy session, but you saved plenty this week. Enjoy it!",
                    "Over target now, way under for the week. You can afford this."
                ]];
            }
            return ["Running hot", [
                "At this rate you're out in $5$. Coffee break soon?",
                "In the zone! Just a little ahead of the clock.",
                "Burning bright. Breathe, sip some water, carry on."
            ]];
        }

        // At or below pace
        if (lastDay && d7 < 60) {
            return ["Spend it!", [
                "Only $4$% used and $2$ to go. Time for that wild idea!",
                "Your week resets in $2$. Spend like it's payday!",
                "So many tokens, so little time. Big refactor, anyone?"
            ]];
        }
        if (left5 == null) {
            return ["Fully charged", [
                "A fresh 5 hours is waiting. What shall we build?",
                "Nothing running, all fresh. Pick something fun!"
            ]];
        }
        if (pace7 < 5 && d7 < 5) {
            return ["Fresh week", [
                "Brand new week, clean slate. Dream big!",
                "Full tank, open road. Where to?"
            ]];
        }
        if (h5 < 20 && d7 < 20) {
            return ["Wide open", [
                "Tokens for days. Go build something silly!",
                "Barely a dent. Are you on holiday? Good for you!",
                "All this room! Maybe try that side project?"
            ]];
        }
        if (on5 && on7) {
            return ["Right on pace", [
                "Smack on target, both of them. Keep this rhythm!",
                "Steady as she goes. You make this look easy.",
                "Pacing like a pro. Nothing to fix here, carry on!"
            ]];
        }
        if (left5 <= 45 * 60 && h5 < 40) {
            return ["Refill soon", [
                "Lots left, refill in $1$. Squeeze in one more?",
                "$1$ until reset at just $3$%. Last call for a big prompt!"
            ]];
        }
        if (on7) {
            return ["Cruising", [
                "Week is on target, and there's room right now. Lovely.",
                "On track for the week. This is the sweet spot."
            ]];
        }
        if (on5) {
            return ["Nice rhythm", [
                "Good pace this session, and lots of week to spare.",
                "On target now, ahead of the game this week. Enjoy!"
            ]];
        }
        return ["Plenty left", [
            "Well under target. Got an idea you've been putting off?",
            "Easy does it. There's plenty in the tank if you want to push.",
            "Cool, calm and under budget. Nice going!"
        ]];
    }
}
