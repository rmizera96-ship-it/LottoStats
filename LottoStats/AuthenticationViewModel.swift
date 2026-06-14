import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var email: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isListening = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    var isAuthenticated: Bool {
        userID != nil
    }

    func startListening() {
        guard authStateHandle == nil else {
            return
        }

        isListening = true
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.userID = user?.uid
                self?.email = user?.email
                self?.isListening = false
            }
        }
    }

    func signIn(email: String, password: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Podaj adres e-mail i hasło."
            return
        }

        beginOperation()

        Auth.auth().signIn(withEmail: normalizedEmail, password: password) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                self.finishOperation(error: error, successMessage: "Zalogowano pomyślnie.")
            }
        }
    }

    func register(email: String, password: String, repeatedPassword: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedEmail.isEmpty else {
            errorMessage = "Podaj adres e-mail."
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Hasło musi mieć co najmniej 6 znaków."
            return
        }

        guard password == repeatedPassword else {
            errorMessage = "Podane hasła nie są identyczne."
            return
        }

        beginOperation()

        Auth.auth().createUser(withEmail: normalizedEmail, password: password) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                self.finishOperation(
                    error: error,
                    successMessage: "Konto zostało utworzone. Lokalne kupony zostaną zsynchronizowane."
                )
            }
        }
    }

    func sendPasswordReset(email: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedEmail.isEmpty else {
            errorMessage = "Wpisz adres e-mail, na który ma zostać wysłany link."
            return
        }

        beginOperation()

        Auth.auth().sendPasswordReset(withEmail: normalizedEmail) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.finishOperation(
                    error: error,
                    successMessage: "Jeśli konto istnieje, wysłaliśmy wiadomość z linkiem do zmiany hasła."
                )
            }
        }
    }

    func signOut() {
        errorMessage = nil
        infoMessage = nil

        do {
            try Auth.auth().signOut()
            infoMessage = "Wylogowano z konta."
        } catch {
            errorMessage = userFriendlyMessage(for: error)
        }
    }

    func clearMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    private func beginOperation() {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
    }

    private func finishOperation(error: Error?, successMessage: String) {
        isLoading = false

        if let error {
            errorMessage = userFriendlyMessage(for: error)
            infoMessage = nil
        } else {
            errorMessage = nil
            infoMessage = successMessage
        }
    }

    private func userFriendlyMessage(for error: Error) -> String {
        let nsError = error as NSError

        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return "Wystąpił błąd logowania. Spróbuj ponownie."
        }

        switch code {
        case .invalidEmail:
            return "Adres e-mail ma nieprawidłowy format."
        case .emailAlreadyInUse:
            return "Konto z tym adresem e-mail już istnieje."
        case .weakPassword:
            return "Hasło jest zbyt słabe. Użyj co najmniej 6 znaków."
        case .wrongPassword, .invalidCredential:
            return "Nieprawidłowy adres e-mail lub hasło."
        case .userNotFound:
            return "Nie znaleziono konta z tym adresem e-mail."
        case .userDisabled:
            return "To konto zostało wyłączone."
        case .networkError:
            return "Brak połączenia z internetem. Sprawdź sieć i spróbuj ponownie."
        case .tooManyRequests:
            return "Wykonano zbyt wiele prób. Spróbuj ponownie później."
        case .operationNotAllowed:
            return "Logowanie e-mailem nie jest włączone w konfiguracji Firebase."
        default:
            return nsError.localizedDescription
        }
    }
}
