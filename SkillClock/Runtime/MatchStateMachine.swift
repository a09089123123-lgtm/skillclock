import Foundation

enum MatchTransition {
    case started(UUID)
    case ended(UUID)
    case interrupted(UUID)
    case resumed(UUID)
}

struct MatchStateMachine {
    private(set) var phase: MatchPhase = .idle
    private(set) var matchID: UUID?
    private var hudVotes = 0
    private var settlementVotes = 0
    private var settlementUnknownVotes = 0

    mutating func reduce(_ signal: SceneSignal) -> [MatchTransition] {
        switch signal {
        case .gameHUD:
            settlementVotes = 0
            settlementUnknownVotes = 0
            if phase == .interrupted, let matchID {
                phase = .inMatch
                hudVotes = 3
                return [.resumed(matchID)]
            }
            guard phase == .idle || phase == .loading else { return [] }
            hudVotes += 1
            guard hudVotes >= 3 else { return [] }
            return beginMatch()
        case .victory, .defeat:
            hudVotes = 0
            if phase == .settlement {
                settlementUnknownVotes += 1
                if settlementUnknownVotes >= 5 {
                    reset()
                }
                return []
            }
            settlementUnknownVotes = 0
            guard phase == .inMatch || phase == .loading else {
                settlementVotes = 0
                return []
            }
            settlementVotes += 1
            guard settlementVotes >= 2, let matchID else { return [] }
            phase = .settlement
            return [.ended(matchID)]
        case .loading:
            hudVotes = 0
            settlementVotes = 0
            settlementUnknownVotes = 0
            if phase == .idle {
                phase = .loading
            }
            return []
        case .nonGame:
            hudVotes = 0
            settlementVotes = 0
            settlementUnknownVotes = 0
            if phase == .settlement {
                reset()
            }
            return []
        case .unknown:
            hudVotes = 0
            settlementVotes = 0
            if phase == .settlement {
                settlementUnknownVotes += 1
                if settlementUnknownVotes >= 5 {
                    reset()
                }
            }
            return []
        }
    }

    mutating func interrupt() -> [MatchTransition] {
        guard let matchID, phase == .inMatch || phase == .loading else {
            reset()
            return []
        }
        phase = .interrupted
        hudVotes = 0
        settlementVotes = 0
        settlementUnknownVotes = 0
        return [.interrupted(matchID)]
    }

    mutating func reset() {
        phase = .idle
        matchID = nil
        hudVotes = 0
        settlementVotes = 0
        settlementUnknownVotes = 0
    }

    mutating func beginTraining() -> UUID {
        let id = UUID()
        matchID = id
        phase = .inMatch
        hudVotes = 3
        settlementVotes = 0
        settlementUnknownVotes = 0
        return id
    }

    private mutating func beginMatch() -> [MatchTransition] {
        let id = UUID()
        matchID = id
        phase = .inMatch
        hudVotes = 3
        settlementVotes = 0
        settlementUnknownVotes = 0
        return [.started(id)]
    }
}
