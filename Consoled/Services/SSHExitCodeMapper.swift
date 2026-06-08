import Foundation

enum SSHExitCodeMapper {
    static func message(for exitCode: Int32) -> String {
        switch exitCode {
        case 0:
            return "SSH session ended normally."
        case 1:
            return "SSH exited with a generic error."
        case 2:
            return "SSH usage error (invalid arguments or options)."
        case 255:
            return "SSH connection or authentication failed."
        case 6...127:
            return mappedOpenSSHMessage(for: exitCode) ?? "SSH exited with status \(exitCode)."
        default:
            return "SSH exited with status \(exitCode)."
        }
    }

    private static func mappedOpenSSHMessage(for exitCode: Int32) -> String? {
        switch exitCode {
        case 6:
            return "Could not resolve hostname."
        case 10:
            return "Requested service is not available on the remote host."
        case 11:
            return "Protocol negotiation failed."
        case 12:
            return "SSH key exchange failed."
        case 13:
            return "Host key verification failed."
        case 14:
            return "SSH key file permissions or format problem."
        case 15:
            return "SSH key file is protected with a passphrase and could not be used."
        case 16:
            return "Permission denied (publickey, password, or keyboard-interactive)."
        case 17:
            return "Too many authentication failures."
        case 18:
            return "Disconnected by the remote host."
        case 19:
            return "No route to host."
        case 20:
            return "Connection timed out."
        case 21:
            return "Connection refused."
        case 22:
            return "Network is unreachable."
        case 23:
            return "Address already in use (local port forward conflict)."
        case 24:
            return "Cannot assign requested address."
        case 25:
            return "Port forwarding setup failed."
        default:
            return nil
        }
    }
}
