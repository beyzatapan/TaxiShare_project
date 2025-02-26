import SwiftUI
import FirebaseFirestore
import Foundation
import GoogleSignIn
import CoreLocation
import GoogleMaps
import CoreLocation


struct MatchView: View {
    @State private var matchedName: String? // Eşleşen kişinin adı ve soyadı
    @State private var statusMessage = "Eşleşme Aranıyor..."
    @State private var matchedEmail: String?
    @State private var commonDistance: Double = 0.0
    @State private var matchedRoute: [(Double, Double)] = []
    
    @State private var commonRoute: [(Double, Double)] = [] 
    @State private var isMapReady = false
    @Environment(\.presentationMode) var presentationMode 
    @State private var radiusMatches: [(email: String, start: (Double, Double), end: (Double, Double))] = []
    @State private var userRoute: [(Double, Double)] = [] 
    @State private var isRouteCalculated = false 

    @State private var matchedNameRadius: String = "Eşleşen kişinin adı alınamadı"
    @State private var totalDistance: String = "0 km"
    @State private var totalDuration: String = "0 dakika"
    @State private var taxiCostMessage: String? = nil
    @State private var matchedUserCost: Double = 0.0

    
    
    
    init(userRoute: [(Double, Double)]) {
        self._userRoute = State(initialValue: userRoute)
    }
    
    
    var currentUserEmail: String {
        GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
    }
    
    var body: some View {
        ZStack {
            // Harita görünümü tüm ekranı kaplar
            if isMapReady {
                GoogleMapView(userRoute: userRoute, matchedRoute: matchedRoute, commonRoute: commonRoute)
                    .ignoresSafeArea(edges: .all)
            }
            
            VStack {
                // Çarpı işareti sağ üst köşede
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss() // Sayfayı kapat
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding(.top, 10) // Çarpıyı biraz yukarı yerleştir
                .padding(.trailing, 10) // Sağ tarafa hizala
                
                // Kullanıcı eşleşme bilgileri
                VStack(alignment: .leading, spacing: 10) {
                    
                    if let email = matchedEmail {
                        Text("Eşleşme Sağlandı!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        
                        if let name = matchedName {
                            Text("Eşleşen Kullanıcı: \(name)") // Ad ve soyadı göster
                                .font(.body)
                        } else {
                            Text("Eşleşen Kullanıcı: \(email)") // E-posta göster
                                .font(.body)
                        }
                        
                      
                        Text("Ortak Gidilecek Mesafe: \(commonDistance, specifier: "%.2f") km")
                            .font(.body)
                        
                        if let taxiCostMessage = taxiCostMessage {
                            Text(taxiCostMessage)
                                .font(.headline)
                                .foregroundColor(.orange)
                                .padding()
                                .background(Color.black.opacity(0.6)) // Arka plan şeffaf siyah
                                .cornerRadius(10)
                        }

                    } else {
                        Text(statusMessage)
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                }
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding(.horizontal)
                .padding(.top, 10) // Sayfanın üstüne yaslamak için az bir boşluk bırak
                
                Spacer()
               
                if  !radiusMatches.isEmpty && !isRouteCalculated {
                    Button(action: {
                        DispatchQueue.global(qos: .userInitiated).async { 

                            if let firstMatch = radiusMatches.first,
                               let currentUserStart = userRoute.first,
                               let currentUserEnd = userRoute.last {
                                
                                let user1Start = "\(currentUserStart.0),\(currentUserStart.1)"
                                let user1End = "\(currentUserEnd.0),\(currentUserEnd.1)"
                                let user2Start = "\(firstMatch.start.0),\(firstMatch.start.1)"
                                let user2End = "\(firstMatch.end.0),\(firstMatch.end.1)"
                                
                                calculateBestRoute(
                                    user1Start: user1Start,
                                    user1End: user1End,
                                    user2Start: user2Start,
                                    user2End: user2End,
                                    matchedEmail: firstMatch.email 
                                )
                                //  isRouteCalculated = true 
                                DispatchQueue.main.async { 
                                    isRouteCalculated = true 
                                }
                            }
                        }
                        
                    }) {
                        Text("Farklı rota tercihlerinde eşleşme sağlandı git")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
                
                if isRouteCalculated {
                    Button(action: {
                        acceptMatch()
                        print("Eşleşme kabul edildi!")
                        presentationMode.wrappedValue.dismiss() 
                        
                    }) {
                        Text("Eşleşmeyi Kabul Et ")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
                
                
                
                
        
                if matchedEmail != nil && !isRouteCalculated {
                    Button(action: {
                        
                        acceptMatch() 
                        presentationMode.wrappedValue.dismiss()
                        
                        print("Eşleşme kabul edildi!")
                    }) {
                        Text("Eşleşmeyi Kabul Et")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20) 
                    
                    
                }
            }
        }
        .onAppear {
            findBestMatch()
            findRadiusMatchesForCurrentUser()
            if let matchedEmail = matchedEmail, !commonRoute.isEmpty {
                    calculateTaxiCost(
                        currentUserEmail: currentUserEmail,
                        matchedEmail: matchedEmail,
                        commonRoute: commonRoute
                    ) { user1Cost, user2Cost in
                        DispatchQueue.main.async {
                            self.taxiCostMessage = "Tahmini Taksi Ücreti: \(String(format: "%.2f", user1Cost)) TL"
                        }
                    }
                }
            
            }
        .onChange(of: matchedEmail) { oldValue, newValue in
            if let matchedEmail = newValue, !commonRoute.isEmpty {
                calculateTaxiCost(
                    currentUserEmail: currentUserEmail,
                    matchedEmail: matchedEmail,
                    commonRoute: commonRoute
                ) { user1Cost, user2Cost in
                    DispatchQueue.main.async {
                        self.taxiCostMessage = "Tahmini Taksi Ücreti: \(String(format: "%.2f", user1Cost)) TL"
                        self.matchedUserCost = user2Cost 

                    }
                }
            }
        }

        
    }
    
        
        
        func calculateBestRoute(user1Start: String, user1End: String, user2Start: String, user2End: String, matchedEmail: String) {
            getRadiusBestRoute(
                user1Start: user1Start,
                user1End: user1End,
                user2Start: user2Start,
                user2End: user2End,
                apiKey: "AIzaSyDvbBK2347QE9BWJsWYZzgjiP3yTLypCAI",
                matchedEmail: matchedEmail
            ) { bestRouteCoords, bestDistance, bestDuration, email, name, distanceInKm, status in
                
                if let bestRouteCoords = bestRouteCoords {
                    DispatchQueue.main.async {
                        print("En iyi rota bulundu: \(bestRouteCoords)")
                        self.userRoute = bestRouteCoords 
                        self.commonRoute = bestRouteCoords
                        self.isMapReady = false 
                        self.isMapReady = false 
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.isMapReady = true
                            
                        }
                        
                        self.userRoute = bestRouteCoords ?? []
                        self.matchedEmail = email
                        self.matchedName = name
                        self.commonDistance = distanceInKm
                        self.statusMessage = status
                        print("calculateBestRoute - Toplam Mesafe: \(distanceInKm) km")
                        
                        
                        
                    }
                } else {
                    DispatchQueue.main.async {
                        print("Aynı rota üzerinde uygun rota bulunamadı.")
                    }
                }
            }
        }
        
        
        func acceptMatch() {
            let db = Firestore.firestore()
            let currentUserEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "Anonim Kullanıcı"
            
            
            
            let matchData: [String: Any] = [
                "matchedEmail": matchedEmail ?? "",
                "commonDistance": commonDistance,
                "status": "pending", 
                "initiator": currentUserEmail,
                "matchedUserCost": matchedUserCost 

            ]
            
        
            db.collection("users").document(matchedEmail ?? "").collection("notifications").addDocument(data: matchData) { error in
                if let error = error {
                    print("Hata: \(error.localizedDescription)")
                } else {
                    print("Bildirim başarıyla gönderildi.")
                }
            }
        }
        
        
        
        
        func fetchRoutesFromFirebase(completion: @escaping ([(String, [(Double, Double)])]) -> Void) {
            let db = Firestore.firestore()
            var routes: [(String, [(Double, Double)])] = []
            
            db.collection("routes").getDocuments { (snapshot, error) in
                if let error = error {
                    print("Firebase Hata: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                for document in documents {
                    let data = document.data()
                    let email = data["userEmail"] as? String ?? "Bilinmeyen Kullanıcı"
                    if email == currentUserEmail {
                        continue
                    }
                    
                    if let coordinates = data["coordinates"] as? [[String: Double]] {
                        let route = coordinates.compactMap { coord in
                            if let latitude = coord["latitude"], let longitude = coord["longitude"] {
                                return (latitude, longitude)
                            }
                            return nil
                        }
                        routes.append((email, route))
                    }
                }
                completion(routes)
            }
        }
        
    func findBestMatch() {
        let frechetTolerance: Double = 5.0 

        fetchRoutesFromFirebase { routes in
            guard !routes.isEmpty else {
                statusMessage = "Hiç Rota Bulunamadı"
                return
            }

            
            let filteredRoutes = routes.filter { route in
                frechetDistance(route1: userRoute, route2: route.1) <= frechetTolerance
            }


            let sortedRoutes = filteredRoutes.sorted {
                frechetDistance(route1: userRoute, route2: $0.1) < frechetDistance(route1: userRoute, route2: $1.1)
            }

            for (email, route) in sortedRoutes {
                let commonPoints = findCommonPoints(route1: userRoute, route2: route)
                let calculatedCommonDistance = calculateCommonDistance(route1: userRoute, route2: route)

                if !commonPoints.isEmpty, calculatedCommonDistance >= 2.0 {
                    let userRouteDistance = calculateTotalDistance(userRoute)
                    let matchRouteDistance = calculateTotalDistance(route)

                    let isUserGuest = userRouteDistance < matchRouteDistance
                    let guestRoute = isUserGuest ? userRoute : route

                    let guestStart = guestRoute.first ?? (0.0, 0.0)
                    let guestEnd = guestRoute.last ?? (0.0, 0.0)
                    let commonStart = commonPoints.first ?? (0.0, 0.0)
                    let commonEnd = commonPoints.last ?? (0.0, 0.0)

                    let startingDistance = calculateDistance(from: guestStart, to: commonStart)
                    let endingDistance = calculateDistance(from: commonEnd, to: guestEnd)

                    if startingDistance <= 1.0 && endingDistance <= 1.0 {
                        matchedEmail = email
                        matchedRoute = route
                        commonRoute = commonPoints
                        commonDistance = calculatedCommonDistance
                        fetchMatchedPersonName(for: email)
                        statusMessage = "Eşleşme Sağlandı!"
                        isMapReady = true
                        return 
                    }
                }
            }

         
            statusMessage = "Uygun Rota Bulunamadı"
        }
    }

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
                    self.matchedName = "\(name) \(surname)"
                    
                } else {
                    self.matchedName = nil
                }
            }
        }
        
        
        func calculateTotalDistance(_ route: [(Double, Double)]) -> Double {
            var totalDistance: Double = 0.0
            for i in 0..<route.count - 1 {
                let location1 = CLLocation(latitude: route[i].0, longitude: route[i].1)
                let location2 = CLLocation(latitude: route[i + 1].0, longitude: route[i + 1].1)
                totalDistance += location1.distance(from: location2)
            }
            return totalDistance / 1000.0
            
        }
        
        func findRadiusMatchesForCurrentUser() {
            fetchRoutesFromFirebase { routes in
                let radius = 2.0 
                var matches: [(email: String, start: (Double, Double), end: (Double, Double))] = []
                
                for (email, route) in routes {
                    guard let currentUserStart = userRoute.first,
                          let currentUserEnd = userRoute.last,
                          let otherUserStart = route.first,
                          let otherUserEnd = route.last else {
                        continue
                    }
                    if currentUserStart == otherUserStart && currentUserEnd == otherUserEnd {
                        print("Başlangıç ve varış noktaları tamamen aynı. Bu eşleşme görmezden gelinecek.")
                        continue
                    }
                    let startDistance = calculateDistance(from: currentUserStart, to: otherUserStart)
                    let endDistance = calculateDistance(from: currentUserEnd, to: otherUserEnd)
                    
                    if startDistance <= radius && endDistance <= radius {
                        matches.append((email: email, start: otherUserStart, end: otherUserEnd))
                    }
                }
                
                DispatchQueue.main.async {
                    if matches.isEmpty {
                        print("Eşleşme bulunamadı. Başlangıç ve varış noktaları aynı olabilir.")
                    }
                    self.radiusMatches = matches
                }
            }
        }
        
        func calculateDistance(from: (Double, Double), to: (Double, Double)) -> Double {
            let startLocation = CLLocation(latitude: from.0, longitude: from.1)
            let endLocation = CLLocation(latitude: to.0, longitude: to.1)
            return startLocation.distance(from: endLocation) / 1000.0
        }
        
        func findCommonPoints(route1: [(Double, Double)], route2: [(Double, Double)], tolerance: Double = 0.001) -> [(Double, Double)] {
            return route1.filter { p1 in
                route2.contains { p2 in
                    euclideanDistance(p1, p2) <= tolerance
                }
            }
        }
        
    func frechetDistance(route1: [(Double, Double)], route2: [(Double, Double)]) -> Double {
            var dp = Array(repeating: Array(repeating: -1.0, count: route2.count), count: route1.count)
            
            func c(i: Int, j: Int) -> Double {
                guard i >= 0, i < route1.count, j >= 0, j < route2.count else {
                       return Double.infinity
                   }
                if dp[i][j] > -1 {
                    return dp[i][j]
                }
                if i == 0 && j == 0 {
                    dp[i][j] = euclideanDistance(route1[0], route2[0])
                } else if i > 0 && j == 0 {
                    dp[i][j] = max(c(i: i - 1, j: 0), euclideanDistance(route1[i], route2[0]))
                } else if i == 0 && j > 0 {
                    dp[i][j] = max(c(i: 0, j: j - 1), euclideanDistance(route1[0], route2[j]))
                } else if i > 0 && j > 0 {
                    dp[i][j] = max(
                        min(c(i: i - 1, j: j), c(i: i - 1, j: j - 1), c(i: i, j: j - 1)),
                        euclideanDistance(route1[i], route2[j])
                    )
                } else {
                    dp[i][j] = Double.infinity
                }
                return dp[i][j]
            }
            
            return c(i: route1.count - 1, j: route2.count - 1)
        }
        
        func calculateCommonDistance(route1: [(Double, Double)], route2: [(Double, Double)], tolerance: Double = 0.001) -> Double {
            let commonPoints = findCommonPoints(route1: route1, route2: route2, tolerance: tolerance)
            guard commonPoints.count > 1 else { return 0.0 }
            
            var totalDistance: Double = 0.0
            for i in 0..<commonPoints.count - 1 {
                let location1 = CLLocation(latitude: commonPoints[i].0, longitude: commonPoints[i].1)
                let location2 = CLLocation(latitude: commonPoints[i + 1].0, longitude: commonPoints[i + 1].1)
                totalDistance += location1.distance(from: location2)
            }
            
            return totalDistance / 1000.0
        }
        
        func euclideanDistance(_ point1: (Double, Double), _ point2: (Double, Double)) -> Double {
            let dx = point1.0 - point2.0
            let dy = point1.1 - point2.1
            return sqrt(dx * dx + dy * dy)
        }
        
        struct GoogleMapView: UIViewRepresentable {
            var userRoute: [(Double, Double)]
            var matchedRoute: [(Double, Double)]
            var commonRoute: [(Double, Double)]
            
            
            
            
            func makeUIView(context: Context) -> GMSMapView {
                let mapView = GMSMapView(frame: .zero)
                
                
                if !userRoute.isEmpty {
                    let userPath = GMSMutablePath()
                    userRoute.forEach { coord in
                        userPath.add(CLLocationCoordinate2D(latitude: coord.0, longitude: coord.1))
                    }
                    let userPolyline = GMSPolyline(path: userPath)
                    userPolyline.strokeColor = .black
                    userPolyline.strokeWidth = 6.0
                    userPolyline.map = mapView
                }
                
                if !commonRoute.isEmpty {
                    let commonPath = GMSMutablePath()
                    commonRoute.forEach { coord in
                        commonPath.add(CLLocationCoordinate2D(latitude: coord.0, longitude: coord.1))
                    }
                    let commonPolyline = GMSPolyline(path: commonPath)
                    commonPolyline.strokeColor = .orange
                    commonPolyline.strokeWidth = 3.0
                    commonPolyline.map = mapView
                }
                /*
                if !matchedRoute.isEmpty {
                    let matchedPath = GMSMutablePath()
                    matchedRoute.forEach { coord in
                        matchedPath.add(CLLocationCoordinate2D(latitude: coord.0, longitude: coord.1))
                    }
                    let matchedPolyline = GMSPolyline(path: matchedPath)
                    matchedPolyline.strokeColor = .green
                    matchedPolyline.strokeWidth = 3.0
                    matchedPolyline.map = mapView
                }
                 */
                
                if let firstCoord = userRoute.first {
                    let camera = GMSCameraPosition(latitude: firstCoord.0, longitude: firstCoord.1, zoom: 12)
                    mapView.camera = camera
                }
                
                return mapView
            }
            
            func updateUIView(_ uiView: GMSMapView, context: Context) {}
        }
    }
    
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
    
    func getRadiusBestRoute(
        user1Start: String,
        user1End: String,
        user2Start: String,
        user2End: String,
        apiKey: String,
        matchedEmail: String,
        completion: @escaping ([(Double, Double)]?, Int?, Int?, String, String, Double, String) -> Void
    ) {
        if user1Start == user2Start && user1End == user2End {
            print("Başlangıç ve varış noktaları tamamen aynı. İşlem yapılmayacak.")
            
            return
        }
        var combinations: [(String, String?, String?, String)] = []
        
        
        if user1Start != user2Start && user1End != user2End {
            combinations = [
                (user1Start, user2Start, user2End, user1End),
                (user1Start, user2Start, user1End, user2End),
                (user2Start, user1Start, user1End, user2End),
                (user2Start, user1Start, user2End, user1End)
            ]
        } else if user1Start == user2Start {
            combinations = [
                (user1Start, nil, user2End, user1End),
                (user1Start, nil, user1End, user2End)
            ]
        } else if user1End == user2End {
            combinations = [
                (user1Start, user2Start, nil, user1End),
                (user2Start, user1Start, nil, user1End)
            ]
        }
        
        var bestDistance = Int.max
        var bestDuration = Int.max
        var bestRouteCoords: [(Double, Double)] = []
        var decodedPolyline: [(Double, Double)] = []
        
        
        let group = DispatchGroup()
        
        for combination in combinations {
            group.enter()
            
            let (start1, start2, end2, end1) = combination
            let waypoints = [start2, end2].compactMap { $0 }.joined(separator: "|")
            let url = "https://maps.googleapis.com/maps/api/directions/json?origin=\(start1)&destination=\(end1)&waypoints=\(waypoints)&key=\("AIzaSyDvbBK2347QE9BWJsWYZzgjiP3yTLypCAI")"
            
            guard let requestURL = URL(string: url) else {
                group.leave()
                continue
            }
            
            URLSession.shared.dataTask(with: requestURL) { data, response, error in
                defer { group.leave() }
                
                guard let data = data, error == nil else {
                    print("API Hatası: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let routes = json["routes"] as? [[String: Any]],
                       let firstRoute = routes.first {
                        
                        
                        if let overviewPolyline = firstRoute["overview_polyline"] as? [String: String],
                           let encodedPolyline = overviewPolyline["points"] {
                      
                            decodedPolyline = decodePolyline(encodedPolyline)
                            
                        }
                        
                   
                        if let legs = firstRoute["legs"] as? [[String: Any]],
                           let firstLeg = legs.first,
                           let distance = firstLeg["distance"] as? [String: Any],
                           let duration = firstLeg["duration"] as? [String: Any],
                           let distanceValue = distance["value"] as? Int,
                           let durationValue = duration["value"] as? Int {
                            
                            if distanceValue < bestDistance || (distanceValue == bestDistance && durationValue < bestDuration) {
                                bestDistance = distanceValue
                                bestDuration = durationValue
                                bestRouteCoords = decodedPolyline
                                print("getRadiusBestRoute - Toplam Mesafe: \(bestDistance ) km") 
                                
                            }
                        }
                    }
                } catch {
                    print("JSON Hatası: \(error.localizedDescription)")
                }
            }.resume()
        }
        
        group.notify(queue: .main) {
            let distanceInKm = Double(bestDistance) / 1000.0
            print("getRadiusBestRoute - Toplam Mesafe: \(distanceInKm) km") 
            

            
            fetchMatchedPersonName(for: matchedEmail) { matchedName in
                let status = bestRouteCoords.isEmpty ? "Uygun rota bulunamadı." : "Eşleşme sağlandı!"
                completion(
                    bestRouteCoords.isEmpty ? nil : bestRouteCoords,
                    bestDistance == Int.max ? nil : bestDistance,
                    bestDuration == Int.max ? nil : bestDuration,
                    matchedEmail,
                    matchedName,
                    distanceInKm, 
                    status
                )
            }
        }
    }
    
    
    func fetchMatchedPersonName(for email: String, completion: @escaping (String) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("users").document(email).getDocument { document, error in
            if let error = error {
                print("Profil bilgisi alınamadı: \(error.localizedDescription)")
                completion("Bilinmeyen")
                return
            }
            
            if let profileData = document?.data()?["profile"] as? [String: Any],
               let name = profileData["name"] as? String,
               let surname = profileData["surname"] as? String {
                completion("\(name) \(surname)")
            } else {
                completion("Bilinmeyen")
            }
        }
    }
    
func calculateTaxiCost(
        currentUserEmail: String,
        matchedEmail: String,
        commonRoute: [(Double, Double)],
        completion: @escaping (Double, Double) -> Void
    ) {
        print("Fonksiyon çağrıldı.")
        print("Matched Email: \(matchedEmail)")
        print("Current User Email: \(currentUserEmail)")
        print("Common Route: \(commonRoute)")
        

        func fetchRouteEndpoints(email: String, completion: @escaping ((start: String, end: String)?) -> Void) {
            let db = Firestore.firestore()
            db.collection("users").document(email).getDocument { document, error in
                guard let data = document?.data()?["routeInfo"] as? [String: Any],
                      let fromLocation = data["fromLocation"] as? String,
                      let toLocation = data["toLocation"] as? String else {
                    print("Firebase'den adres bilgileri alınamadı.")
                    completion(nil)
                    return
                }

                print("Firebase'den çekilen bilgiler: Başlangıç: \(fromLocation), Varış: \(toLocation)")

            
                let geocoder = CLGeocoder()

       
                geocoder.geocodeAddressString(fromLocation) { fromPlacemarks, error in
                    guard let fromCoordinate = fromPlacemarks?.first?.location?.coordinate else {
                        print("Başlangıç noktası bulunamadı.")
                        completion(nil)
                        return
                    }

                   
                    geocoder.geocodeAddressString(toLocation) { toPlacemarks, error in
                        guard let toCoordinate = toPlacemarks?.first?.location?.coordinate else {
                            print("Varış noktası bulunamadı.")
                            completion(nil)
                            return
                        }

                        
                        let startCoord = "\(fromCoordinate.latitude),\(fromCoordinate.longitude)"
                        let endCoord = "\(toCoordinate.latitude),\(toCoordinate.longitude)"
                        print("Başlangıç Koordinatları: \(startCoord), Varış Koordinatları: \(endCoord)")

                        completion((startCoord, endCoord))
                    }
                }
            }
        }

    
        func fetchRouteMetrics(start: String, end: String, completion: @escaping ((distance: Double, duration: Double)?) -> Void) {
            let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(start)&destination=\(end)&key=AIzaSyDvbBK2347QE9BWJsWYZzgjiP3yTLypCAI"
            print("Google Maps API URL: \(urlString)")

            guard let url = URL(string: urlString) else {
                completion(nil)
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, _, error in
                guard error == nil, let data = data else {
                    completion(nil)
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
                       let distanceValue = distanceDict["value"] as? Double,
                       let durationValue = durationDict["value"] as? Double {
                        let distanceInKm = distanceValue / 1000.0
                        let durationInMinutes = durationValue / 60.0
                        print("Google Maps API Mesafe: \(distanceInKm) km, Süre: \(durationInMinutes) dakika")
                        completion((distanceInKm, durationInMinutes))
                    } else {
                        completion(nil)
                        print("Google Maps API'den beklenen formatta veri alınamadı!")

                    }
                } catch {
                    completion(nil)
                    print("JSON Ayrıştırma Hatası: \(error.localizedDescription)")

                }
            }.resume()
        }
        
        
        guard let commonStart = commonRoute.first,
              let commonEnd = commonRoute.last else {
            completion(0.0, 0.0)
            return
        }
        
        let commonStartString = "\(commonStart.0),\(commonStart.1)"
        let commonEndString = "\(commonEnd.0),\(commonEnd.1)"
        print("Common Start: \(commonStartString), Common End: \(commonEndString)")
        
        
        
        fetchRouteEndpoints(email: currentUserEmail) { currentUserRoute in
            guard let currentUserRoute = currentUserRoute else {
                completion(0.0, 0.0)
                return
            }
            fetchRouteEndpoints(email: matchedEmail) { matchedUserRoute in
                 guard let matchedUserRoute = matchedUserRoute else {
                     completion(0.0, 0.0)
                     return
                 }
                
                // Google Maps API ile mesafe ve süre bilgilerini al
                fetchRouteMetrics(start: currentUserRoute.start, end: currentUserRoute.end) { currentUserMetrics in
                    guard let currentUserMetrics = currentUserMetrics else {
                        completion(0.0, 0.0)
                        return
                    }
                    print("Kullanıcı 1 - Mesafe: \(currentUserMetrics.distance) km, Süre: \(currentUserMetrics.duration) dakika")

                    fetchRouteMetrics(start: matchedUserRoute.start, end: matchedUserRoute.end) { matchedUserMetrics in
                        guard let matchedUserMetrics = matchedUserMetrics else {
                            completion(0.0, 0.0)
                            return
                        }
                        print("Kullanıcı 2 - Mesafe: \(matchedUserMetrics.distance) km, Süre: \(matchedUserMetrics.duration) dakika")

                        fetchRouteMetrics(start: commonStartString, end: commonEndString) { commonMetrics in
                            guard let commonMetrics = commonMetrics else {
                                completion(0.0, 0.0)
                                return
                            }
                            print("Ortak Rota - Mesafe: \(commonMetrics.distance) km, Süre: \(commonMetrics.duration) dakika")


                            
                      
                            let openingFee = 30.0 
                            let kmFee = 20.0 
                            let timeFee = 3.92 
                            
                            let user1ExtraDistance = max(0, currentUserMetrics.distance - commonMetrics.distance)
                            let user1ExtraTime = max(0, currentUserMetrics.duration - commonMetrics.duration)
                            print("Kullanıcı 1 Ekstra Mesafe: \(user1ExtraDistance) km, Ekstra Süre: \(user1ExtraTime) dakika")

                            let user2ExtraDistance = matchedUserMetrics.distance - commonMetrics.distance
                            let user2ExtraTime = matchedUserMetrics.duration - commonMetrics.duration
                            print("Kullanıcı 2 Ekstra Mesafe: \(user2ExtraDistance) km, Ekstra Süre: \(user2ExtraTime) dakika")

                            let sharedOpeningFee = openingFee / 2
                            let sharedDistanceCost = (commonMetrics.distance * kmFee) / 2
                            let sharedTimeCost = (commonMetrics.duration * timeFee) / 2
                            
                            let user1TotalCost = sharedOpeningFee +
                            (user1ExtraDistance * kmFee) +
                            (user1ExtraTime * timeFee) +
                            sharedDistanceCost + sharedTimeCost
                            
                            let user2TotalCost = sharedOpeningFee +
                            (user2ExtraDistance * kmFee) +
                            (user2ExtraTime * timeFee) +
                            sharedDistanceCost + sharedTimeCost
                    
                            print("Kullanıcı 1 Ücreti: \(user1TotalCost)")
                            print("Kullanıcı 2 Ücreti: \(user2TotalCost)")
                            completion(user1TotalCost, user2TotalCost)
                        }
                    }
                }
            }
        }
    }
    
