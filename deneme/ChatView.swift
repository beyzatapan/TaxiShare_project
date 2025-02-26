import SwiftUI
import Firebase
import FirebaseFirestore

struct ChatView: View {
    @Environment(\.presentationMode) var presentationMode // Geri dönüş için gerekli
    @State private var messages: [Message] = [] // Mesajları bir model kullanarak tutuyoruz
    @State private var newMessage = ""
    let chatID: String
    let currentUserEmail: String

    var body: some View {
          VStack {
              // Üstte geri düğmesi
              HStack {
                  Button(action: {
                      presentationMode.wrappedValue.dismiss() // Geri dönüş yapar
                  }) {
                      Image(systemName: "arrow.left")
                          .font(.system(size: 24))
                          .padding()
                          .foregroundColor(.orange)
                  }
                  Spacer()
              }
              .padding(.leading)

              ScrollView {
                  LazyVStack(alignment: .leading, spacing: 10) {
                      ForEach(messages) { message in
                          HStack {
                              if message.sender == currentUserEmail {
                                  Spacer()
                                  Text(message.content)
                                      .padding()
                                      .background(Color.orange)
                                      .foregroundColor(.white)
                                      .cornerRadius(10)
                              } else {
                                  Text(message.content)
                                      .padding()
                                      .background(Color.gray.opacity(0.2))
                                      .cornerRadius(10)
                                  Spacer()
                              }
                          }
                      }
                  }
              }
              .padding()

              HStack {
                  TextField("Mesaj yazın...", text: $newMessage)
                      .textFieldStyle(RoundedBorderTextFieldStyle())
                      .padding()

                  Button(action: sendMessage) {
                      Image(systemName: "paperplane.fill")
                          .font(.system(size: 24))
                          .foregroundColor(.orange)
                          .padding()
                  }
              }
              .padding(.bottom)
          }
          .onAppear {
              fetchMessages()
          }
      }


    func fetchMessages() {
        let db = Firestore.firestore()
        db.collection("chats").document(chatID).collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Hata: \(error.localizedDescription)")
                    return
                }

                messages = snapshot?.documents.compactMap { document in
                    let data = document.data()
                    guard let sender = data["sender"] as? String,
                          let content = data["message"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    return Message(id: document.documentID, sender: sender, content: content, timestamp: timestamp.dateValue())
                } ?? []
            }
    }

    func sendMessage() {
        guard !newMessage.isEmpty else { return }
        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "sender": currentUserEmail,
            "message": newMessage,
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("chats").document(chatID).collection("messages")
            .addDocument(data: messageData) { error in
                if let error = error {
                    print("Mesaj gönderme hatası: \(error.localizedDescription)")
                } else {
                    newMessage = ""
                }
            }
    }
}

struct Message: Identifiable {
    let id: String
    let sender: String
    let content: String
    let timestamp: Date
}

