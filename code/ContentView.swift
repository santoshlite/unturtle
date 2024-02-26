import SwiftUI
import UserNotifications
import AVFoundation


class NotificationManager: ObservableObject {
    static let shared = NotificationManager() 
    
    let randomNotifications: [String] = ["If slouching were anle Olympic sport, you’d be taking home the gold.", "Even a shrimp stands straighter than you right now.", "If you were any more bent, you'd be a boomerang.", "Your spine's more curved than a question mark – straighten up!", "Your xposture’s so slouched, you’re practically inventing a new yoga pose.", "You're slouching so much, you might find oil down there.", "You're bending like you're bowing to your computer. Let's not worship technology too much!"
    ]
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Permission granted")
            } else if let error = error {
                print("Permission denied with error: \(error.localizedDescription)")
            }
        }
    }
    
    func triggerNotification() {
        let content = UNMutableNotificationContent()
        
        if let randomMessage = randomNotifications.randomElement() {
            content.title = "💢 Unturtle is Angry"
            content.body = randomMessage
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView: View {
    @State private var showSessionButtons = false
    @State var isCalibrating: Bool = true
    @State private var showingAlert = false
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        NavigationSplitView {
            VStack {
                Image("turtle").resizable().frame(minWidth: 50, maxWidth: 125, minHeight: 50, maxHeight: 125)
                Text("Unturtle")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 5)
                Text("Your Posture's Companion")
                    .font(.callout)
                    .padding(.bottom, 30)
                
                if !showSessionButtons{
                    
                    Button {
                        withAnimation{
                            showingAlert = true
                        }
                    } label: {
                        Label("Start", systemImage: "studentdesk")
                            .font(.title3)
                            .bold()
                            .padding(3)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green).transition(.scale)
                    .alert(isPresented: $showingAlert){
                        Alert(
                            title: Text("Start Tracking Posture"),
                            message: Text("Sit upright and stay still just until calibration concludes after you tap 'Start'. \n\nUnturtle will then seamlessly start tracking your posture in the background."),
                            primaryButton: .default(Text("Start")) {
                                showSessionButtons = true
                                isCalibrating = true
                                notificationManager.requestNotificationPermission()
                            },
                            secondaryButton: .cancel(Text("Wait, no!"))
                        )
                    }
                    
                } else {
                    HStack {
                        Button {
                            isCalibrating = true
                        } label: {
                            Label("Recalibrate", systemImage: "ruler.fill")
                                .font(.title3)
                                .bold()
                                .padding(3)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue).transition(.scale)
                        
                        Button {
                            withAnimation{
                                showSessionButtons = false
                            }
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.title3)
                                .bold()
                                .padding(3)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red).transition(.scale)
                    }
                }
            }
        } detail: {
            if showSessionButtons {
                SessionView(isCalibrating: $isCalibrating)
            } else {
                VStack{
                    Text("Click on Start to get started!")
                        .font(.headline)
                }
            }
        }
    }
    
}



struct SessionView: View {
    @State private var landmarks: BodyLandmarks3D?
    @Binding var isCalibrating: Bool
    @State private var goodPosture: Bool = true
    @State private var calibrateCalled: Bool = false
    @State private var calibrationValues: [Float] = []
    @State private var trackingCalled: Bool = false
    @State private var trackingValues: [Float] = []
    @State private var consecutiveFailures = 0
    @State private var lastNotificationTime: Date? = nil
    @State private var calibrationPosition: [String : Float] = 
    ["headZ" : 0.0, 
     "headY": 0.0
    ]
    @EnvironmentObject var notificationManager: NotificationManager
    
    func calibrate() {
        if calibrateCalled { return }
        guard calibrationValues.isEmpty else { return }
        calibrateCalled = true
        let totalFires = Int(3.0 / 0.1)
        var fireCount = 0 
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if let headZ = self.landmarks?.centerHead?.z {
                self.calibrationValues.append(headZ)
            }
            fireCount += 1
            
            if fireCount == totalFires {
                timer.invalidate() 
                let sum = calibrationValues.reduce(0.0, +) 
                let averageHeadZ: Float = sum / Float(calibrationValues.count)
                calibrationPosition["headZ"] = averageHeadZ
                isCalibrating = false
                calibrationValues = []
                calibrateCalled = false
            }
            
        }
    }
    
    func checkPosture() {
        if trackingCalled { return }
        guard trackingValues.isEmpty else { return }
        trackingCalled = true
        let totalFires = Int(1.0 / 0.1)
        var fireCount = 0 
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if let headZ = self.landmarks?.centerHead?.z {
                self.trackingValues.append(headZ)
            }
            fireCount += 1
            
            if fireCount == totalFires {
                timer.invalidate() 
                let sortedValues = self.trackingValues.sorted()

                var closestValue = sortedValues.first ?? 0.0
                if let headZRef = calibrationPosition["headZ"] {
                    closestValue = sortedValues.min(by: { abs($0 - headZRef) < abs($1 - headZRef) }) ?? closestValue

                    if abs(headZRef - closestValue) >= 0.10 && abs(headZRef - closestValue) <= 1.0 {
                        goodPosture = false
                        consecutiveFailures += 1 
                        
                        if consecutiveFailures >= 3 && (lastNotificationTime == nil || Date().timeIntervalSince(lastNotificationTime!) >= 60) {
                            notificationManager.triggerNotification()
                            lastNotificationTime = Date()  
                            consecutiveFailures = 0 
                        }
                    } else {
                        goodPosture = true
                        consecutiveFailures = 0 
                    }
                }
                
                trackingValues = []
                trackingCalled = false
            }
        }
    }
    
    var CameraViewFinder: some View {
        CameraView { detectedLandmarks in
            DispatchQueue.main.async { 
                self.landmarks = detectedLandmarks
                
                if isCalibrating{
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        calibrate()
                    }
                } else{
                    checkPosture()
                }
                
            }
        }
        
        .ignoresSafeArea()
    } 
    
    var body: some View {
        ZStack {
            CameraViewFinder
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .bottom)
            
            VStack {
                Spacer()
                
                if isCalibrating{
                    Feedback(imageName: "gear", feedback: "Calibrating...")
                }
                
                if goodPosture && !isCalibrating {
                    Feedback(imageName: "up", feedback: "Great posture")
                }
                
                if !goodPosture && !isCalibrating {
                    Feedback(imageName: "down", feedback: "Fix your posture.\nYou can also Recalibrate if needed!")
                }
                
            }
        }
    }
}


