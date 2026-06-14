import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var repeatedPassword = ""

    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Logowanie"
        case register = "Rejestracja"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(
                        title: mode == .signIn ? "Zaloguj się" : "Utwórz konto",
                        subtitle: "Synchronizuj zapisane kupony między urządzeniami.",
                        icon: mode == .signIn ? "person.crop.circle.fill" : "person.crop.circle.badge.plus",
                        tint: mode == .signIn ? AppTheme.accent : Color.purple
                    )

                    modeSelector
                    formCard
                }
                .padding()
                .safeAreaPadding(.bottom, 30)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Konto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.clearMessages()
            }
            .onChange(of: mode) { _, _ in
                password = ""
                repeatedPassword = ""
                viewModel.clearMessages()
            }
            .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    dismiss()
                }
            }
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 7) {
            ForEach(Mode.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(mode == item ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if mode == item {
                                LinearGradient(
                                    colors: [modeTint, modeTint.opacity(0.68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                Color(.tertiarySystemFill)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var formCard: some View {
        AppCard(tint: modeTint) {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: mode.rawValue,
                    subtitle: mode == .signIn
                        ? "Wprowadź dane swojego konta Firebase"
                        : "Konto zostanie utworzone przy użyciu e-maila i hasła",
                    icon: mode == .signIn ? "lock.open.fill" : "person.badge.plus",
                    tint: modeTint
                )

                VStack(spacing: 12) {
                    TextField("Adres e-mail", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .authFieldStyle(icon: "envelope.fill", tint: modeTint)

                    SecureField("Hasło", text: $password)
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .authFieldStyle(icon: "key.fill", tint: modeTint)

                    if mode == .register {
                        SecureField("Powtórz hasło", text: $repeatedPassword)
                            .textContentType(.newPassword)
                            .authFieldStyle(icon: "checkmark.shield.fill", tint: modeTint)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    AppMessageBanner(
                        icon: "exclamationmark.triangle.fill",
                        text: errorMessage,
                        tint: .red
                    )
                }

                if let infoMessage = viewModel.infoMessage {
                    AppMessageBanner(
                        icon: "checkmark.circle.fill",
                        text: infoMessage,
                        tint: .green
                    )
                }

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: mode == .signIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                        }

                        Text(mode == .signIn ? "Zaloguj się" : "Utwórz konto")
                    }
                }
                .buttonStyle(
                    PrimaryActionButtonStyle(
                        tint: modeTint,
                        isEnabled: canSubmit && !viewModel.isLoading
                    )
                )
                .disabled(!canSubmit || viewModel.isLoading)

                if mode == .signIn {
                    Button("Nie pamiętam hasła") {
                        viewModel.sendPasswordReset(email: email)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(modeTint)
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.isLoading)
                }

                Text("Bez logowania aplikacja nadal działa lokalnie. Po zalogowaniu kupony są zapisywane także na Twoim koncie w chmurze.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var modeTint: Color {
        mode == .signIn ? AppTheme.accent : .purple
    }

    private var canSubmit: Bool {
        let hasBaseData = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty

        if mode == .register {
            return hasBaseData && !repeatedPassword.isEmpty
        }

        return hasBaseData
    }

    private func submit() {
        switch mode {
        case .signIn:
            viewModel.signIn(email: email, password: password)
        case .register:
            viewModel.register(
                email: email,
                password: password,
                repeatedPassword: repeatedPassword
            )
        }
    }
}

private extension View {
    func authFieldStyle(icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 22)

            self
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
    }
}
