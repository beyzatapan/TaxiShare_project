import GoogleMaps
import SwiftUI

// BestRadiusGoogleMapView burada tanımlanır
struct BestRadiusGoogleMapView: UIViewRepresentable {
    var bestRoute: [(Double, Double)]

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: .zero)
        
        if !bestRoute.isEmpty {
            print("bestRoute dolu, harita gösteriliyor: \(bestRoute)")
            let path = GMSMutablePath()
            
            bestRoute.forEach { coord in
                path.add(CLLocationCoordinate2D(latitude: coord.0, longitude: coord.1))
            }
            
            let polyline = GMSPolyline(path: path)
            polyline.strokeColor = .red
            polyline.strokeWidth = 5.0
            polyline.map = mapView
            
            if let firstCoord = bestRoute.first {
                let camera = GMSCameraPosition(latitude: firstCoord.0, longitude: firstCoord.1, zoom: 12)
                mapView.camera = camera
            }
        }
        if bestRoute.isEmpty {
            print("Rota bilgisi boş!")
            return mapView
        }
        
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {}
}

// BestRadiusRouteView burada tanımlanır
struct BestRadiusRouteView: View {
    var user1Start: String
    var user1End: String
    var user2Start: String
    var user2End: String
    var apiKey: String
    
    @State private var bestRoute: [(Double, Double)] = []
    @State private var isMapReady = false
    @State private var statusMessage = "En İyi Rota Hesaplanıyor..."
    
    var body: some View {
        ZStack {
            if isMapReady {
                BestRadiusGoogleMapView(bestRoute: bestRoute)
                    .ignoresSafeArea(edges: .all)
            } else {
                Text(statusMessage)
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding()
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        // Sayfayı kapatmak için
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            print("User1 Start: \(user1Start)")
            print("User1 End: \(user1End)")
            print("User2 Start: \(user2Start)")
            print("User2 End: \(user2End)")

            calculateBestRoute()
        }
    }
    
    func calculateBestRoute() {
        let combinations = [
            (user1Start, user2Start, user2End, user1End),
            (user1Start, user2End, user2Start, user1End),
            (user2Start, user1Start, user1End, user2End),
            (user2Start, user1End, user1Start, user2End)
        ]
        
        var bestDistance = Int.max
        var bestDuration = Int.max
        var bestRoute: [(Double, Double)] = []
        
        let dispatchGroup = DispatchGroup()
        
        for combination in combinations {
            let (start1, start2, end2, end1) = combination
            let waypoints = "\(start2)|\(end2)"
            let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(start1)&destination=\(end1)&waypoints=\(waypoints)&key=\("AIzaSyDvbBK2347QE9BWJsWYZzgjiP3yTLypCAI")"
            
            guard let url = URL(string: urlString) else {
                print("Geçersiz URL: \(urlString)")
                continue
            }
            print("API'ye çağrı yapılıyor: \(urlString)")
            
            dispatchGroup.enter()
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { dispatchGroup.leave() }
                
                guard let data = data, error == nil else {
                    print("API Hatası: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let routes = json["routes"] as? [[String: Any]],
                       let firstRoute = routes.first,
                       let legs = firstRoute["legs"] as? [[String: Any]],
                       let firstLeg = legs.first,
                       let distanceDict = firstLeg["distance"] as? [String: Any],
                       let durationDict = firstLeg["duration"] as? [String: Any],
                       let distanceValue = distanceDict["value"] as? Int,
                       let durationValue = durationDict["value"] as? Int {
                        
                        if distanceValue < bestDistance || durationValue < bestDuration {
                            bestDistance = distanceValue
                            bestDuration = durationValue
                            
                            let routeCoords = firstLeg["steps"] as? [[String: Any]] ?? []
                            bestRoute = routeCoords.compactMap { step in
                                if let endLocation = step["end_location"] as? [String: Double],
                                   let lat = endLocation["lat"],
                                   let lng = endLocation["lng"] {
                                    return (lat, lng)
                                }
                                return nil
                            }
                        }
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                                   print("Dönen JSON: \(json)")
                               }
                    }
                } catch {
                    
                    print("JSON Parse Hatası: \(error.localizedDescription)")
                }
            }.resume()
        }
        
        dispatchGroup.notify(queue: .main) {
            if bestRoute.isEmpty {
                statusMessage = "Uygun rota bulunamadı."
            } else {
                self.bestRoute = bestRoute
                self.isMapReady = true
                statusMessage = "En iyi rota hesaplandı."
            }
        }
    }

}

