import SwiftUI
import Firebase
import GoogleSignIn

struct MatchedView: View {
    @State private var matchedPerson: [String: Any]? = nil
     @State private var matchedPersonName: String? = nil
     @State private var isLoading = true
     @State private var showChatView = false
     @State private var activeTab = 1
     @State private var showHomeView = false
     @State private var showMatchedView = false
     @State private var showAccountView = false

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Yükleniyor...")
                    .padding()
            } else if let matchedPerson = matchedPerson {
                VStack(spacing: 20) {
                                    if let name = matchedPersonName {
                                        Text("Eşleşen Kullanıcı: \(name)")
                                            .font(.headline)
                                    } else {
                                        Text("Eşleşen Kullanıcı: \(matchedPerson["matchedEmail"] as? String ?? "Bilinmiyor")")
                                            .font(.headline)
                                    }

                                    Text("Ortak Mesafe: \(matchedPerson["commonDistance"] as? Double ?? 0.0, specifier: "%.2f") km")
                                        .font(.subheadline)
                    
                    
                    
                    Button(action: {
                        showChatView = true
                    }) {
                        Text("Sohbet Başlat")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                    }
                    .fullScreenCover(isPresented: $showChatView) {
                        // matchedPerson unwrap edilmiş olduğu için opsiyonel zincirleme gereksiz
                        if let matchedEmail = matchedPerson["matchedEmail"] as? String {
                            ChatView(
                                chatID: createChatID(for: matchedEmail),
                                currentUserEmail: getCurrentUserEmail()
                            )
                        } else {
                            Text("Geçersiz eşleşme bilgisi.")
                        }
                    }
                }
            } else {
                Text("Eşleşmiş kimse bulunmamaktadır.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            }
            
            Spacer()

                        // Alt menü düğmeleri
                        HStack {
                            Button(action: {
                                activeTab = 0
                                showHomeView = true
                            }) {
                                Image(systemName: "house.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .padding()
                                    .foregroundColor(activeTab == 0 ? .orange : .gray)
                            }
                            .fullScreenCover(isPresented: $showHomeView) {
                                HomeView()
                            }

                            Spacer()

                            Button(action: {
                                activeTab = 1
                                showMatchedView = true
                            }) {
                                Image("Adsız tasarım")
                                    .resizable()
                                    .clipShape(Circle())
                                    .frame(width: 60, height: 60)
                                    .padding()
                            }
                            .fullScreenCover(isPresented: $showMatchedView) {
                                MatchedView()
                            }

                            Spacer()

                            Button(action: {
                                activeTab = 2
                                showAccountView = true
                            }) {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .padding()
                                    .foregroundColor(activeTab == 2 ? .orange : .gray)
                            }
                            .fullScreenCover(isPresented: $showAccountView) {
                                AccountView()
                            }
                        }
                        .padding(.horizontal)
                        .background(Color.white)
                        .frame(maxWidth: .infinity, maxHeight: 80)
                        .background(Color(.systemGray6))
                    }
                    .onAppear {
                        fetchMatchedPerson()
                    }
                }
    
    
    
    

    func fetchMatchedPerson() {
        isLoading = true
        let db = Firestore.firestore()
        let currentUserEmail = getCurrentUserEmail()

        db.collection("users").document(currentUserEmail).getDocument { document, error in
            isLoading = false
            if let error = error {
                print("Hata: \(error.localizedDescription)")
                return
            }

            if let data = document?.data(), let matchedPerson = data["matchedPerson"] as? [String: Any] {
                self.matchedPerson = matchedPerson
                
                // Matched email adresine sahip kullanıcının profil bilgilerini al
                    if let matchedEmail = matchedPerson["matchedEmail"] as? String {
                        fetchMatchedPersonName(for: matchedEmail)
                    }
                
            } else {
                self.matchedPerson = nil
            }
        }
    }
    /// Eşleşen kişinin ad ve soyad bilgilerini çek
    func fetchMatchedPersonName(for email: String) {
        let db = Firestore.firestore()

        db.collection("users").document(email).getDocument { document, error in
            if let error = error {
                print("Profil bilgisi alınamadı: \(error.localizedDescription)")
                return
            }

            if let profileData = document?.data()?["profile"] as? [String: Any],
               let name = profileData["name"] as? String,
               let surname = profileData["surname"] as? String {
                self.matchedPersonName = "\(name) \(surname)"
            } else {
                self.matchedPersonName = nil
            }
        }
    }

    func createChatID(for otherUserEmail: String) -> String {
        let currentUserEmail = getCurrentUserEmail()
        return [currentUserEmail, otherUserEmail].sorted().joined(separator: "_")
    }

    func getCurrentUserEmail() -> String {
        return GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
    }
}
