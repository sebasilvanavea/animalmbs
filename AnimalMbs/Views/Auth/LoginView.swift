import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            PawPrintBackground(opacity: 0.06, count: 15)

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)

                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.appHeader)
                                .frame(width: 100, height: 100)
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: Color.appPrimary.opacity(0.3), radius: 10, y: 5)

                        Text("AnimalMbs")
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .foregroundStyle(Color.appTextPrimary)

                        Text("La hoja clínica de tu mascota")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Correo electrónico", systemImage: "envelope")
                                .font(.appCaptionBold)
                                .foregroundStyle(Color.appTextSecondary)
                            TextField("tu@email.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(14)
                                .background(Color.appCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label("Contraseña", systemImage: "lock")
                                .font(.appCaptionBold)
                                .foregroundStyle(Color.appTextSecondary)
                            SecureField("Mínimo 6 caracteres", text: $password)
                                .textContentType(isRegistering ? .newPassword : .password)
                                .padding(14)
                                .background(Color.appCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
                                )
                        }

                        if isRegistering {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Confirmar contraseña", systemImage: "lock.shield")
                                    .font(.appCaptionBold)
                                    .foregroundStyle(Color.appTextSecondary)
                                SecureField("Repite la contraseña", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding(14)
                                    .background(Color.appCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Error
                    if let error = authManager.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.appCaption)
                        .foregroundStyle(Color.appDanger)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Action button
                    Button {
                        submit()
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: isRegistering ? "person.badge.plus" : "arrow.right.circle.fill")
                                Text(isRegistering ? "Crear cuenta" : "Iniciar sesión")
                            }
                        }
                        .font(.appHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? LinearGradient.appHeader : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                    .padding(.horizontal)

                    // Toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isRegistering.toggle()
                            confirmPassword = ""
                            authManager.errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isRegistering ? "¿Ya tienes cuenta?" : "¿No tienes cuenta?")
                                .foregroundStyle(Color.appTextSecondary)
                            Text(isRegistering ? "Inicia sesión" : "Regístrate")
                                .foregroundStyle(Color.appPrimary)
                                .fontWeight(.semibold)
                        }
                        .font(.appSubheadline)
                    }

                    // Sync note
                    HStack(spacing: 6) {
                        Image(systemName: "icloud.fill")
                        Text("Tus datos se sincronizan entre la app y la web")
                    }
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextTertiary)
                    .padding(.top, 8)

                    Spacer()
                }
            }
        }
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        if isRegistering {
            return emailValid && passwordValid && password == confirmPassword
        }
        return emailValid && passwordValid
    }

    private func submit() {
        Task {
            if isRegistering {
                await authManager.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
            } else {
                await authManager.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            }
        }
    }
}
