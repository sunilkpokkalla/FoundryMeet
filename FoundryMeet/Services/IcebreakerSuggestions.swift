import Foundation

/// Short openers for the first message after a coffee-chat accept.
enum IcebreakerSuggestions {
    static func prompts(me: UserProfile?, them: DiscoveryCandidate, limit: Int = 3) -> [String] {
        var prompts: [String] = []

        if let looking = them.lookingFor?.trimmingCharacters(in: .whitespacesAndNewlines), !looking.isEmpty {
            prompts.append("You mentioned looking for \(looking.lowercased()) — happy to dig into that.")
        } else if let goal = them.goal?.trimmingCharacters(in: .whitespacesAndNewlines), !goal.isEmpty {
            prompts.append("Curious how you're approaching \(goal.lowercased()) right now.")
        }

        if let help = them.canHelpWith?.trimmingCharacters(in: .whitespacesAndNewlines), !help.isEmpty {
            prompts.append("I'd love to hear more about how you help with \(help.lowercased()).")
        } else if them.buildingIdea?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            prompts.append("Would love to hear more about what you're building.")
        }

        let mySkills = Set((me?.skills ?? []).map { $0.lowercased() })
        if let shared = them.tags.first(where: { mySkills.contains($0.lowercased()) }) {
            prompts.append("Looks like we both know \(shared) — what's been working for you lately?")
        }

        if let myGoal = me?.goal?.trimmingCharacters(in: .whitespacesAndNewlines), !myGoal.isEmpty {
            prompts.append("I'm focused on \(myGoal.lowercased()) — open to swapping notes over coffee?")
        }

        if let location = them.location?.trimmingCharacters(in: .whitespacesAndNewlines),
           !location.isEmpty,
           !LocationParts.isRemote(location) {
            prompts.append("Are you still based in \(location)? Happy to meet virtually or nearby.")
        }

        let defaults = [
            "Thanks for accepting — what's the best thing you're working on this week?",
            "Looking forward to our coffee. What should we prioritize talking about?",
            "Glad we connected. Where should we start when we chat?"
        ]
        for line in defaults where prompts.count < limit && !prompts.contains(line) {
            prompts.append(line)
        }

        return Array(prompts.prefix(limit))
    }
}
