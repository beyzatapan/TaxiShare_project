import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn

struct LoginScreen: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showSignInForm = false // Kayıt formunu gösterme durumu
    @EnvironmentObject var appState: AppState


    var body: some View {
        VStack {
            Image("LoginScreenImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .padding(.bottom, 20)
            
            Text("TaxiShare'e Hoş Geldin")
                .foregroundColor(.orange)
                .font(.system(size: 27, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 40)

            /*
            TextField("Email", text: $username)
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
                .padding(.bottom, 20)

            SecureField("Password", text: $password)
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
                .padding(.bottom, 20)
             */
      
                        CustomTextField(placeholder: "Email", text: $username, systemImage: "envelope.fill")
                            .padding(.bottom, 20)

                        // Password SecureField with Icon Inside
                        CustomTextField(placeholder: "Password", text: $password, systemImage: "lock.fill", isSecure: true)
                            .padding(.bottom, 20)

            Button(action: {
                           // Firebase ile giriş işlemi
                           Auth.auth().signIn(withEmail: username, password: password) { authResult, error in
                               if let error = error {
                                   print("Giriş hatası: \(error.localizedDescription)")
                               } else {
                                   appState.isLoggedIn = true
                               }
                           }
                       }) {
                           Text("Giriş Yap")
                               .foregroundColor(.white)
                               .padding()
                               .frame(maxWidth: .infinity)
                               .background(Color.orange)
                               .cornerRadius(10)
                       }
                       .padding(.horizontal, 50)
                       .padding(.bottom, 10)
            
            
           
            Button(action: {
                googleSignIn()
            }) {
                HStack {
                    Image(systemName: "g.circle")
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .cornerRadius(10)
            }
            .padding(.horizontal, 50)
            .padding(.bottom, 20)
            
        
            Button(action: {
                showSignInForm = true // Kayıt formunu göster
            }) {
                Text("Kaydol")
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .padding(.top, 10)
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showSignInForm) {
            SignInFormView()
        }
    }

    private func googleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            guard error == nil else {
                print("Google Sign-In error: \(error!.localizedDescription)")
                return
            }

            // Başarıyla oturum açıldığında, kullanıcının bilgileriyle işlemleri gerçekleştirin
            if let user = signInResult?.user {
                print("Google user signed in: \(user.profile?.name ?? "Unknown")")
                appState.isLoggedIn = true // Kullanıcı giriş yaptı
            }
        }
    }
}

struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        LoginScreen()
    }
}

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var systemImage: String
    var isSecure: Bool = false

    var body: some View {
        ZStack {
            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .padding(.leading, 10)
                } else {
                    TextField(placeholder, text: $text)
                        .padding(.leading, 10)
                }
                Spacer()
                Image(systemName: systemImage)
                    .foregroundColor(.gray)
                    .padding(.trailing, 10)
            }
            .padding()
            .background(Color.orange.opacity(0.2))
            .cornerRadius(10)
        }
    }
}
