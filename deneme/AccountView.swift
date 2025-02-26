
import SwiftUI
import Firebase
import GoogleSignIn
import FirebaseAuth

struct AccountView: View {
    @State private var notifications: [[String: Any]] = []
    @State private var profile: [String: Any]? = nil
    @State private var showForm = false
    @State private var name = ""
    @State private var surname = ""
    @State private var showConfirmation = false
    @State private var selectedNotification: [String: Any]?
    @State private var acceptedMatch: [String: Any]? = nil
    @State private var matchedPerson: [String: Any]? = nil
    @State private var activeTab = 2
    @State private var showMatchedView = false
    @State private var showAccountView = false
    @State private var showRouteView = false
    @State private var showHomeView = false
    @State private var initiatorNames: [String: String] = [:] // E-posta adresi ile ad-soyad eşleştirmesi
    @State private var dots = "" // Noktaları tutan state
    @State private var timer: Timer? // Timer referansı
    @State private var userRouteInfo: [String: Any]? = nil // Kullanıcının routeInfo bilgisi
    @EnvironmentObject var appState: AppState




    var body: some View {
            VStack(spacing: 20) {

                Image("AccountImage")
                               .resizable()
                               .scaledToFit()
                               .frame(width: 200, height: 200)
                               .padding(.bottom, 20)
                               .ignoresSafeArea(edges: .top)  // Ekranın üst kısmını kapla

                if !name.isEmpty && !surname.isEmpty {
                    Text("Hoş Geldin \(name) \(surname)")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom, 10)
                          }
                
                if showForm {
                    // Kullanıcı bilgisi eksikse form göster
                    Text("Lütfen bilgilerinizi tamamlayın.")
                        .font(.headline)
                    TextField("Ad", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    TextField("Soyad", text: $surname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    Button(action: {
                        saveProfile()
                        self.showForm = false

                    }) {
                        Text("Kaydet")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                } else if let match = acceptedMatch {
                    // Eşleşme bilgileri

                 
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Eşleşme Bilgileri")
                            .font(.title2)
                            .bold()
                            .padding(.bottom, 10)
                       
                        if let matchedEmail = match["matchedEmail"] as? String {
                                 Text("Eşleşen Kullanıcı: \(initiatorNames[matchedEmail] ?? "Yükleniyor...")")
                                     .font(.headline)
                                     .onAppear {
                                         fetchInitiatorName(for: matchedEmail)
                                     }
                             } else {
                                 Text("Eşleşen Kullanıcı: Bilinmiyor")
                                     .font(.headline)
                             }
                        
                        Text("Ortak Gidilecek Mesafe: \(match["commonDistance"] as? Double ?? 0.0, specifier: "%.2f") km")
                            .font(.subheadline)
                        Text("Başlangıç Noktası: \(match["fromLocation"] as? String ?? "Bilinmiyor")")
                            .font(.subheadline)
                        Text("Varış Noktası: \(match["toLocation"] as? String ?? "Bilinmiyor")")
                            .font(.subheadline)
                        
                        
                        Button(action: {
                                  deleteRoute() // Mevcut rotayı silme işlemi
                              }) {
                                  Text("Eşleşmeyi İptal Et")
                                      .foregroundColor(.white)
                                      .padding()
                                      .frame(maxWidth: .infinity)
                                      .background(Color.red)
                                      .cornerRadius(10)
                              }
                              .padding(.top, 10)
                        
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                } else if notifications.isEmpty {
                    if let match = matchedPerson {
                           // Eğer matchedPerson doluysa eşleşme bilgilerini göster
                           VStack(alignment: .leading, spacing: 10) {
                               Text("Eşleşme Bilgileri")
                                   .font(.title2)
                                   .bold()
                                   .padding(.bottom, 10)
                               
                               Text("Eşleşen Kullanıcı: \(match["matchedEmail"] as? String ?? "Bilinmiyor")")
                                   .font(.headline)
                               Text("Başlangıç Noktası: \(match["fromLocation"] as? String ?? "Bilinmiyor")")
                                   .font(.subheadline)
                               Text("Varış Noktası: \(match["toLocation"] as? String ?? "Bilinmiyor")")
                                   .font(.subheadline)
                               if let status = match["status"] as? String {
                                   Text("Durum: \(status)")
                                       .font(.subheadline)
                                       .foregroundColor(.blue)
                               }
                               Button(action: {
                                              deleteRoute()
                                          }) {
                                              Text("Eşleşmeyi İptal Et")
                                                  .foregroundColor(.white)
                                                  .padding()
                                                  .frame(maxWidth: .infinity)
                                                  .background(Color.red)
                                                  .cornerRadius(10)
                                          }
                             
                           }
                           .padding()
                           .background(Color.white)
                           .cornerRadius(10)
                           .shadow(radius: 5)
                           .padding(.horizontal)
                       }
                    
                     else if matchedPerson == nil {
                                VStack(spacing: 10) {
                                    Text("Hiç bildiriminiz yok.")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                        .font(.system(size: 29, weight: .bold))
                                        .padding(.bottom, 40)

                                    
                                    // Dinamik nokta animasyonu
                                    Text("Eşleşme Aranıyor\(dots)")
                                        .foregroundColor(.orange)
                                        .font(.headline)
                                        .onAppear {
                                            startDotAnimation() // Timer başlatılır
                                            fetchRouteInfo() // Kullanıcının routeInfo'sunu çek
                                        }
                                        .onDisappear {
                                            stopDotAnimation() // Timer durdurulur
                                        }
                                    if let routeInfo = userRouteInfo {
                                                    VStack(alignment: .leading, spacing: 10) {
                                                        Text("Eşleşme Aranan Rota:")
                                                            .font(.title3)
                                                            .fontWeight(.semibold)
                                                        Text("Başlangıç Noktası: \(routeInfo["fromLocation"] as? String ?? "Bilinmiyor")")
                                                            .font(.subheadline)
                                                        Text("Varış Noktası: \(routeInfo["toLocation"] as? String ?? "Bilinmiyor")")
                                                            .font(.subheadline)
                                                        if let timestamp = routeInfo["timestamp"] as? Timestamp {
                                                            Text("Tarih: \(formattedDate(timestamp.dateValue()))")
                                                                .font(.subheadline)
                                                                .foregroundColor(.gray)
                                                        }
                                                        
                                                        // Eşleşmeyi Sil Butonu
                                                           Button(action: {
                                                               deleteRoute()
                                                           }) {
                                                               Text("Rotayı Sil ")
                                                                   .foregroundColor(.white)
                                                                   .padding()
                                                                   .frame(maxWidth: .infinity)
                                                                   .background(Color.red)
                                                                   .cornerRadius(10)
                                                           }
                                                        
                                                    }
                                                    .padding()
                                                    .background(Color.white.opacity(0.9))
                                                    .cornerRadius(10)
                                                    .shadow(radius: 5)
                                                    .padding(.horizontal)
                                    }
                                }
                         
                            }
                    
                } else {
                    ScrollView {
                        ForEach(notifications.indices, id: \.self) { index in
                            let notification = notifications[index]
                            let initiatorEmail = notification["initiator"] as? String ?? "Bilinmiyor"
                            let initiatorName = initiatorNames[initiatorEmail] ?? "Yükleniyor..."
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Eşleşen Kullanıcı: \(initiatorName)")
                                    .font(.headline)
                                Text("Ortak Mesafe: \(notification["commonDistance"] as? Double ?? 0.0, specifier: "%.2f") km")
                                     .font(.subheadline)
                                Text("Tahmini Ücret: \(notification["matchedUserCost"] as? Double ?? 0.0, specifier: "%.2f") TL")
                                     .font(.subheadline)
                                     
                                HStack {
                                    Button(action: {
                                        acceptMatch(notification: notification)
                                    }) {
                                        Text("Kabul Et")
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.green)
                                            .cornerRadius(10)
                                    }
                                    
                                    Button(action: {
                                        rejectMatch(notification: notification)
                                    }) {
                                        Text("Reddet")
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.red)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding(.horizontal)
                            .onAppear {
                                        fetchInitiatorName(for: initiatorEmail)
                                    }
                        }
                    }
                }
                
                
                Spacer()
               
                
        
                
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
                                 logout()
                             }) {
                                 Image(systemName: "person.crop.circle.badge.xmark")
                                     .resizable()
                                     .aspectRatio(contentMode: .fit)
                                     .frame(width: 40, height: 40)
                                     .padding()
                                     .foregroundColor(activeTab == 2 ? .orange : .gray)
                             }
                         }
                         .padding(.horizontal)
                         .background(Color.white)
                         .frame(maxWidth: .infinity, maxHeight: 80)
                         .background(Color(.systemGray6))
                
                Spacer()
        
                
                
                
                
                
                     }
                
            .onAppear {
                fetchProfile()
                fetchNotifications()
                fetchMatchedPerson()
                
            }
            .alert(isPresented: $showConfirmation) {
                Alert(title: Text("Eşleşme Tamamlandı"), message: Text("Eşleşme başarıyla onaylandı!"), dismissButton: .default(Text("Tamam")))
            }
        }

    func logout() {
            GIDSignIn.sharedInstance.signOut()
        appState.isLoggedIn = false  // Kullanıcı giriş yaptı
        }



    private func deleteRoute() {
        guard let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email else {
            print("Kullanıcı e-posta bilgisi bulunamadı.")
            return
        }
        
        let db = Firestore.firestore()
        let userDocument = db.collection("users").document(currentUserEmail)
        
        // Kullanıcının matchedPerson bilgisini kontrol et ve sil
        userDocument.getDocument { snapshot, error in
            if let error = error {
                print("Kullanıcı dökümanı alınırken hata: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("Kullanıcı dökümanı mevcut değil.")
                return
            }
            
            if let matchedPerson = data["matchedPerson"] as? [String: Any],
               let matchedEmail = matchedPerson["matchedEmail"] as? String {
                // Kullanıcının matchedPerson bilgisini sil
                userDocument.updateData(["matchedPerson": FieldValue.delete()]) { error in
                    if let error = error {
                        print("Kullanıcının matchedPerson bilgisi silinirken hata: \(error.localizedDescription)")
                    } else {
                        print("Kullanıcının matchedPerson bilgisi başarıyla silindi.")
                    }
                }
                
                // Eşleştiği kişinin matchedPerson bilgisini sil
                let matchedUserDocument = db.collection("users").document(matchedEmail)
                matchedUserDocument.updateData(["matchedPerson": FieldValue.delete()]) { error in
                    if let error = error {
                        print("Eşleştiği kişinin matchedPerson bilgisi silinirken hata: \(error.localizedDescription)")
                    } else {
                        print("Eşleştiği kişinin matchedPerson bilgisi başarıyla silindi.")
                    }
                }
            } else {
                print("Kullanıcının matchedPerson alanı bulunamadı.")
            }
        }
        
        // Kullanıcının routes koleksiyonundaki rotasını sil
        if let documentID = userRouteInfo?["documentID"] as? String {
            db.collection("routes").document(documentID).delete { error in
                if let error = error {
                    print("Route silinirken hata oluştu: \(error.localizedDescription)")
                } else {
                    print("Route başarıyla silindi.")
                }
            }
        }
        
        // Kullanıcının users koleksiyonundaki routeInfo alanını sil
        userDocument.updateData(["routeInfo": FieldValue.delete()]) { error in
            if let error = error {
                print("Kullanıcının routeInfo bilgisi silinirken hata: \(error.localizedDescription)")
            } else {
                print("Kullanıcının routeInfo bilgisi başarıyla silindi.")
            }
        }
    }

   
    func fetchRouteInfo() {
        let db = Firestore.firestore()
        guard let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email else {
            print("Kullanıcı e-postası alınamadı.")
            return
        }

        db.collection("users").document(currentUserEmail).getDocument { document, error in
            if let error = error {
                print("Hata: \(error.localizedDescription)")
                return
            }

            if let data = document?.data(), let routeInfo = data["routeInfo"] as? [String: Any] {
                DispatchQueue.main.async {
                    self.userRouteInfo = routeInfo
                }
            } else {
                print("Rota bilgisi bulunamadı.")
            }
        }
    }
    
    func fetchMatchedPerson() {
        let db = Firestore.firestore()
        let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
        
        // Kullanıcının matchedPerson bilgilerini al
        db.collection("users").document(currentUserEmail).getDocument { document, error in
            if let error = error {
                print("Hata: \(error.localizedDescription)")
                return
            }
            
            guard let data = document?.data() else {
                print("Kullanıcı dökümanı bulunamadı.")
                DispatchQueue.main.async {
                    self.acceptedMatch = nil
                }
                return
            }
            
            // matchedPerson bilgisi varsa, state'i güncelle
            if let matchedPerson = data["matchedPerson"] as? [String: Any] {
                DispatchQueue.main.async {
                    self.acceptedMatch = matchedPerson
                }
            } else {
                DispatchQueue.main.async {
                    self.acceptedMatch = nil
                }
            }
        }
    }


    
    
    
    
    
    
        func startDotAnimation() {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if dots.count >= 3 {
                    dots = ""
                } else {
                    dots += "."
                }
            }
        }
        
        func stopDotAnimation() {
            timer?.invalidate()
            timer = nil
        }
        
        func fetchUserRouteInfo() {
            let db = Firestore.firestore()
            let email = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
            let userDocument = db.collection("users").document(email)
            
            userDocument.getDocument { document, error in
                if let error = error {
                    print("RouteInfo bilgileri alınırken hata oluştu: \(error.localizedDescription)")
                    return
                }
                
                if let data = document?.data(), let routeInfo = data["routeInfo"] as? [String: Any] {
                    DispatchQueue.main.async {
                        self.userRouteInfo = routeInfo
                    }
                } else {
                    print("RouteInfo bilgisi bulunamadı.")
                }
            }
        }
        
        func fetchInitiatorName(for email: String) {
            guard initiatorNames[email] == nil else { return } // Daha önce alınmışsa tekrar almayalım
            let db = Firestore.firestore()
            db.collection("users").document(email).getDocument { document, error in
                if let error = error {
                    print("Hata: \(error.localizedDescription)")
                    return
                }
                
                if let data = document?.data()?["profile"] as? [String: Any],
                   let name = data["name"] as? String,
                   let surname = data["surname"] as? String {
                    DispatchQueue.main.async {
                        initiatorNames[email] = "\(name) \(surname)"
                    }
                } else {
                    DispatchQueue.main.async {
                        initiatorNames[email] = "Bilinmiyor"
                    }
                }
            }
        }
        
        func fetchProfile() {
            let db = Firestore.firestore()
            let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
            db.collection("users").document(currentUserEmail).getDocument { document, error in
                
                if let document = document, document.exists, let data = document.data()?["profile"] as? [String: Any] {
                    self.name = data["name"] as? String ?? ""
                    self.surname = data["surname"] as? String ?? ""
                    self.showForm = self.name.isEmpty || self.surname.isEmpty

                }
                else {
                            // Profil bulunamadıysa formu göster
                            self.showForm = true
                        }
            }
        }
    
        func formattedDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        
        
        // Kullanıcı bilgilerini kaydet
        func saveProfile() {
            let db = Firestore.firestore()
            let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
            
            let profileData: [String: Any] = [
                "name": name,
                "surname": surname
            ]
            
            db.collection("users").document(currentUserEmail).setData(["profile": profileData], merge: true) { error in
                if let error = error {
                    print("Hata: \(error.localizedDescription)")
                } else {
                    self.profile = profileData
                }
            }
        }
        
        /// Bildirimleri Firebase'den getir
        func fetchNotifications() {
            let db = Firestore.firestore()
            let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
            
            db.collection("users").document(currentUserEmail).collection("notifications").getDocuments { snapshot, error in
                if let error = error {
                    print("Hata: \(error.localizedDescription)")
                    return
                }
                
                self.notifications = snapshot?.documents.map { $0.data() } ?? []
            }
    
            
        }
    
  
        

    func acceptMatch(notification: [String: Any]) {
        let db = Firestore.firestore()
        let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
        let matchedEmail = notification["initiator"] as? String ?? ""

        let commonDistance = notification["commonDistance"] as? Double ?? 0.0

        // Önce kendi routeInfo bilgisini al
        db.collection("users").document(currentUserEmail).getDocument { currentUserDocument, error in
            if let error = error {
                print("Kendi routeInfo bilgisi alınamadı: \(error.localizedDescription)")
                return
            }

            guard let currentUserData = currentUserDocument?.data(),
                  let currentUserRouteInfo = currentUserData["routeInfo"] as? [String: Any] else {
                print("Kendi routeInfo bilgisi bulunamadı.")
                return
            }

            // Şimdi matchedEmail'in routeInfo bilgisini al
            db.collection("users").document(matchedEmail).getDocument { matchedUserDocument, error in
                if let error = error {
                    print("Eşleşilen kişinin routeInfo bilgisi alınamadı: \(error.localizedDescription)")
                    return
                }

                guard let matchedUserData = matchedUserDocument?.data(),
                      let matchedUserRouteInfo = matchedUserData["routeInfo"] as? [String: Any] else {
                    print("Eşleşilen kişinin routeInfo bilgisi bulunamadı.")
                    return
                }

                // Kendi bilgilerini matchedEmail'in matchedPerson alanına yaz
                let currentUserMatchDetails: [String: Any] = [
                    "matchedEmail": currentUserEmail,
                    "fromLocation": currentUserRouteInfo["fromLocation"] as? String ?? "Bilinmiyor",
                    "toLocation": currentUserRouteInfo["toLocation"] as? String ?? "Bilinmiyor",
                    "commonDistance": commonDistance,
                    "status": "confirmed"
                ]

                db.collection("users").document(matchedEmail).updateData(["matchedPerson": currentUserMatchDetails]) { error in
                    if let error = error {
                        print("Eşleşilen kişiye matchedPerson bilgisi eklenirken hata oluştu: \(error.localizedDescription)")
                        return
                    }
                    print("Eşleşilen kişiye matchedPerson bilgisi başarıyla eklendi.")
                }

                // Karşı kullanıcının bilgilerini kendi matchedPerson alanına yaz
                let matchedUserMatchDetails: [String: Any] = [
                    "matchedEmail": matchedEmail,
                    "fromLocation": matchedUserRouteInfo["fromLocation"] as? String ?? "Bilinmiyor",
                    "toLocation": matchedUserRouteInfo["toLocation"] as? String ?? "Bilinmiyor",
                    "commonDistance": commonDistance,
                    "status": "confirmed"
                ]

                db.collection("users").document(currentUserEmail).updateData(["matchedPerson": matchedUserMatchDetails]) { error in
                    if let error = error {
                        print("Kendi matchedPerson bilgisi eklenirken hata oluştu: \(error.localizedDescription)")
                        return
                    }
                    print("Kendi matchedPerson bilgisi başarıyla eklendi.")

                    // Bildirimi sil
                    self.deleteNotification(for: currentUserEmail)
                    self.acceptedMatch = matchedUserMatchDetails
                    self.notifications.removeAll { $0["initiator"] as? String == matchedEmail }
                    self.showConfirmation = true
                }
            }
        }
    }

        
    private func deleteNotification(for email: String) {
        let db = Firestore.firestore()
        let userDocument = db.collection("users").document(email)
        
        userDocument.collection("notifications").getDocuments { snapshot, error in
            if let error = error {
                print("Notifications silinirken hata oluştu: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("Notifications dökümanı bulunamadı.")
                return
            }
            
            for document in documents {
                document.reference.delete { error in
                    if let error = error {
                        print("Notification silinirken hata oluştu: \(error.localizedDescription)")
                    } else {
                        print("Notification başarıyla silindi.")
                    }
                }
            }
        }
    }

        
        
        
        func rejectMatch(notification: [String: Any]) {
            let db = Firestore.firestore()
            let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
            let matchedEmail = notification["initiator"] as? String ?? ""
            
            db.collection("users").document(currentUserEmail).collection("notifications").whereField("initiator", isEqualTo: matchedEmail).getDocuments { snapshot, error in
                if let error = error {
                    print("Hata: \(error.localizedDescription)")
                    return
                }
                
                snapshot?.documents.forEach { document in
                    document.reference.delete()
                }
                
                self.notifications.removeAll { $0["initiator"] as? String == matchedEmail }
            }
        }
    }


