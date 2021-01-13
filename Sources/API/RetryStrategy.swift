import Foundation

protocol RetryStrategy {
    func retry<T>(function: () -> Result<T, PushNotificationsAPIError>) -> Result<T, PushNotificationsAPIError>
}

public struct JustDont: RetryStrategy {
    func retry<T>(function: () -> Result<T, PushNotificationsAPIError>) -> Result<T, PushNotificationsAPIError> {
        let result = function()

        switch result {
        case .error(let error):
            print("[PushNotifications]: Network error: \(error.getErrorMessage())")
            return result
        case .value:
            return result
        }
    }
}

public class WithInfiniteExpBackoff: RetryStrategy {
    private var retryCount = 0

    func retry<T>(function: () -> Result<T, PushNotificationsAPIError>) -> Result<T, PushNotificationsAPIError> {
        while true {
            let result = function()

            switch result {
            case .error(let error):
                switch error {
                case .deviceNotFound, .badRequest, .badJWT, .badDeviceToken:
                    // Not recoverable cases.
                    return result
                case .genericError:
                    print("[PushNotifications]: Network error: \(error.getErrorMessage())")
                    self.retryCount += 1
                    let delay = calculateExponentialBackoffMs(attemptCount: self.retryCount)
                    Thread.sleep(forTimeInterval: TimeInterval(delay / 1000.0))
                    continue
                }
            case .value:
                return result
            }
        }
    }

    private let maxExponentialBackoffDelayMs = 64000.0
    private let baseExponentialBackoffDelayMs = 200.0
    private func calculateExponentialBackoffMs(attemptCount: Int) -> Double {
        return min(maxExponentialBackoffDelayMs, baseExponentialBackoffDelayMs * pow(2.0, Double(attemptCount)))
    }
}
