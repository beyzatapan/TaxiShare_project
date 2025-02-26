//
//  RouteView.swift
//  deneme
//
//  Created by Beyza Tapan on 12.12.2024.
//

import SwiftUI
import GoogleMaps
import FirebaseFirestore
import GoogleSignIn

struct RouteView: View {

    let fromLocation: String
    let toLocation: String
    let db = Firestore.firestore()

    @Environment(\.presentationMode) var presentationMode // Çıkış için ortam değişkeni
    @Binding var showRouteView: Bool
    @State private var showMatchView = false
    @State private var distanceText: String = "Mesafe: Hesaplanıyor..."
    @State private var durationText: String = "Süre: Hesaplanıyor..."
    @State private var coordinates: [(Double, Double)] = []

    
    private var userEmail: String {
         GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
     }

    private func saveRouteToFirestore(fromLocation: String, toLocation: String, email: String, coordinates: [(Double, Double)], distance: String, duration: String) {
        let db = Firestore.firestore()
        let encodedEmail = email.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
        
  
        let routeData: [String: Any] = [
            "fromLocation": fromLocation,
            "toLocation": toLocation,
            "userEmail": email,
            "distance": distance,
            "duration": duration,
            "coordinates": coordinates.map { ["latitude": $0.0, "longitude": $0.1] },
            "timestamp": Timestamp(date: Date())
        ]
        
      
        db.collection("routes").document(encodedEmail).setData(routeData) { error in
            if let error = error {
                print("Firestore'a kaydedilirken hata oluştu: \(error.localizedDescription)")
            } else {
                print("Rota bilgileri başarıyla kaydedildi.")
               
                saveRouteToFirestoreUser(fromLocation: fromLocation, toLocation: toLocation, email: email, distance: distance, duration: duration, documentID: encodedEmail)
            }
        }
    }


    private func saveRouteToFirestoreUser(fromLocation: String, toLocation: String, email: String, distance: String, duration: String, documentID: String) {
        let db = Firestore.firestore()
        
       
        let routeData: [String: Any] = [
            "fromLocation": fromLocation,
            "toLocation": toLocation,
            "distance": distance,
            "duration": duration,
            "timestamp": Timestamp(date: Date()),
            "documentID": documentID 
        ]
        
        db.collection("users").document(email).setData(["routeInfo": routeData], merge: true) { error in
            if let error = error {
                print("Users'daki routeInfo alanına kaydedilirken hata oluştu: \(error.localizedDescription)")
            } else {
                print("Users'daki routeInfo alanı başarıyla güncellendi.")
            }
        }
    }

    
    
    
    
    
    
    
    
    
    
    var body: some View {
        ZStack {
            GoogleMapView(fromLocation: fromLocation, toLocation: toLocation, distanceText: $distanceText, durationText: $durationText, coordinates: $coordinates)
                .ignoresSafeArea(edges: .all)
            
            VStack{
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss() 
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding(.top, 20) 
                .padding(.trailing, 20) 
                
                Spacer() 
            }
            VStack {
                VStack {
                    Text(distanceText)
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(durationText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding(.top, 20)

                Spacer()
                
                Button(action: {
                    let email = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
                    saveRouteToFirestore(fromLocation: fromLocation, toLocation: toLocation, email: email, coordinates: coordinates, distance: distanceText, duration: durationText)
                    showMatchView = true
                }) {
                    Text("Git")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.bottom, 20)
                .fullScreenCover(isPresented: $showMatchView) {
                    MatchView(userRoute: coordinates)
           }
                
                
            }
        }
    }
}

struct GoogleMapView: UIViewRepresentable {
    var fromLocation: String
    var toLocation: String
    @Binding var distanceText: String
    @Binding var durationText: String
    @Binding var coordinates: [(Double, Double)] 


    func decodePolyline(_ polyline: String) -> [(Double, Double)] {
        var coordinates: [(Double, Double)] = []
        var index = polyline.startIndex
        let end = polyline.endIndex
        var lat = 0
        var lng = 0

        while index < end {
            var result = 0
            var shift = 0
            var byte: Int
            repeat {
                byte = Int(polyline[index].asciiValue!) - 63
                result |= (byte & 0x1F) << shift
                shift += 5
                index = polyline.index(after: index)
            } while byte >= 0x20
            let deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += deltaLat

            result = 0
            shift = 0
            repeat {
                byte = Int(polyline[index].asciiValue!) - 63
                result |= (byte & 0x1F) << shift
                shift += 5
                index = polyline.index(after: index)
            } while byte >= 0x20
            let deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += deltaLng

            coordinates.append((Double(lat) / 1E5, Double(lng) / 1E5))
        }

        return coordinates
    }
    private func saveCoordinatesToFirestore(coordinates: [(Double, Double)]) {
        let db = Firestore.firestore()
        let routeData: [String: Any] = [
            "coordinates": coordinates.map { ["latitude": $0.0, "longitude": $0.1] },
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("routes").addDocument(data: routeData) { error in
            if let error = error {
                print("Koordinatlar kaydedilirken hata oluştu: \(error.localizedDescription)")
            } else {
                print("Koordinatlar başarıyla kaydedildi.")
            }
        }
    }


    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: UIScreen.main.bounds)
        mapView.isMyLocationEnabled = true
        mapView.settings.compassButton = true
        mapView.settings.zoomGestures = true

        drawRoute(fromLocation: fromLocation, toLocation: toLocation, mapView: mapView)
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {}

    private func drawRoute(fromLocation: String, toLocation: String, mapView: GMSMapView) {
        let geocoder = CLGeocoder()

        geocoder.geocodeAddressString(fromLocation) { fromPlacemarks, error in
            guard let fromCoordinate = fromPlacemarks?.first?.location?.coordinate else {
                print("Başlangıç noktası bulunamadı.")
                return
            }

            let fromMarker = GMSMarker(position: fromCoordinate)
            fromMarker.title = "Başlangıç"
            fromMarker.map = mapView

            geocoder.geocodeAddressString(toLocation) { toPlacemarks, error in
                guard let toCoordinate = toPlacemarks?.first?.location?.coordinate else {
                    print("Varış noktası bulunamadı.")
                    return
                }

       
                let toMarker = GMSMarker(position: toCoordinate)
                toMarker.title = "Varış"
                toMarker.map = mapView

                let origin = "\(fromCoordinate.latitude),\(fromCoordinate.longitude)"
                let destination = "\(toCoordinate.latitude),\(toCoordinate.longitude)"

                let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(destination)&key=AIzaSyBGOyorS8v7x3pMxJpmh2a5mBEV_SuzZb0"

                guard let url = URL(string: urlString) else { return }
                
                URLSession.shared.dataTask(with: url) { data, response, error in
                    guard let data = data else { return }
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let routes = json["routes"] as? [[String: Any]],
                           let route = routes.first,
                           let overviewPolyline = route["overview_polyline"] as? [String: Any],
                           let points = overviewPolyline["points"] as? String,
                           let legs = route["legs"] as? [[String: Any]],
                           let firstLeg = legs.first {
                        
                            let decodedCoordinates = decodePolyline(points)


                   
                            if let distance = firstLeg["distance"] as? [String: Any],
                               let distanceValue = distance["text"] as? String {
                                DispatchQueue.main.async {
                                    self.distanceText = "Mesafe: \(distanceValue)"
                                }
                            }

                            if let duration = firstLeg["duration"] as? [String: Any],
                               let durationValue = duration["text"] as? String {
                                DispatchQueue.main.async {
                                    self.durationText = "Süre: \(durationValue)"
                                }
                            }

                            DispatchQueue.main.async {
                                self.coordinates = decodedCoordinates
                                let path = GMSPath(fromEncodedPath: points)
                                let polyline = GMSPolyline(path: path)
                                polyline.strokeColor = .orange
                                polyline.strokeWidth = 5
                                polyline.map = mapView

                                let bounds = GMSCoordinateBounds(path: path!)
                                mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 50.0))
                            }
                        }
                    } catch {
                        print("JSON Parse Error: \(error.localizedDescription)")
                    }
                }.resume()
            }
        }
    }
}

