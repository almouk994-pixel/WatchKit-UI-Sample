import SwiftUI

struct ContentView: View {
    @State private var currentTV = "sony"
    @State private var isVolumeMode = false
    @State private var touchPoint: CGPoint? = nil
    @State private var isTap = true
    @State private var hasLongPressed = false
    @State private var lastDragLocation: CGPoint = .zero
    @State private var lastCommandTime: Date = Date.distantPast
    
    private let throttleDelay: TimeInterval = 0.1
    private let swipeThreshold: CGFloat = 15.0
    
    // ضع الـ IP الخاص بسيرفر Termux هنا
    let serverBaseURL = "http://192.168.1.15:5000" 

    var body: some View {
        // استخدمنا GeometryReader ليتأقلم مع شاشة الساعة تلقائياً
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Color.white.opacity(0.001)
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { handleTouchMove(value: $0) }
                            .onEnded { handleTouchEnd(value: $0) }
                    )
                
                if let tp = touchPoint {
                    Circle()
                        .fill(hasLongPressed ? Color.red.opacity(0.8) : Color.white.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .position(tp)
                        .allowsHitTesting(false)
                }
                
                // زر التبديل
                Button(action: { currentTV = (currentTV == "sony") ? "samsung" : "sony" }) {
                    Text(currentTV == "sony" ? "📺 SONY" : "📺 SAMSUNG")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(currentTV == "sony" ? Color.orange.opacity(0.4) : Color.blue.opacity(0.4))
                        .cornerRadius(16)
                }
                .position(x: geo.size.width / 2, y: 20)
                
                // زر Home (أعلى اليسار)
                ActionButton(icon: "🏠", color: .white) { safeSendCommand("home") } longPressAction: { safeSendCommand("power") }
                .position(x: 25, y: 25)
                
                // زر Input (أسفل اليسار)
                ActionButton(icon: "📺", color: .white) { safeSendCommand("input") }
                .position(x: 25, y: geo.size.height - 25)
                
                // زر Mode (أعلى اليمين)
                ActionButton(icon: isVolumeMode ? "🔊" : "🕹️", color: isVolumeMode ? .green : .white) { isVolumeMode.toggle() }
                .position(x: geo.size.width - 25, y: 25)
                
                // زر Mute (أسفل اليمين)
                ActionButton(icon: "🔇", color: .white) { safeSendCommand("mute") }
                .position(x: geo.size.width - 25, y: geo.size.height - 25)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // منطق اللمس (لا تغيير فيه لأنه يعمل بشكل ممتاز)
    func handleTouchMove(value: DragGesture.Value) {
        let currentX = value.location.x
        let currentY = value.location.y
        
        if touchPoint == nil {
            isTap = true
            hasLongPressed = false
            lastDragLocation = value.location
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if isTap {
                    hasLongPressed = true
                    safeSendCommand("back")
                }
            }
        }
        
        touchPoint = value.location
        let dx = currentX - lastDragLocation.x
        let dy = currentY - lastDragLocation.y
        
        if hypot(dx, dy) > 10 { isTap = false }
        
        if abs(dx) > swipeThreshold || abs(dy) > swipeThreshold {
            var cmdToSend: String? = nil
            if abs(dx) > abs(dy) {
                if !isVolumeMode { cmdToSend = dx > 0 ? "right" : "left" }
            } else {
                if dy > 0 { cmdToSend = isVolumeMode ? "voldown" : "down" } 
                else { cmdToSend = isVolumeMode ? "volup" : "up" }
            }
            
            if let cmd = cmdToSend {
                safeSendCommand(cmd)
                lastDragLocation = value.location
            }
        }
    }
    
    func handleTouchEnd(value: DragGesture.Value) {
        if isTap && !hasLongPressed { safeSendCommand("enter") }
        touchPoint = nil
    }
    
    func safeSendCommand(_ cmd: String) {
        let now = Date()
        if now.timeIntervalSince(lastCommandTime) >= throttleDelay {
            lastCommandTime = now
            guard let url = URL(string: "\(serverBaseURL)/\(currentTV)/\(cmd)") else { return }
            URLSession.shared.dataTask(with: url).resume()
        }
    }
}

// تصميم الأزرار الدائرية
struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    var longPressAction: (() -> Void)? = nil
    @State private var isPressed = false
    
    var body: some View {
        Text(icon)
            .font(.system(size: 22))
            .frame(width: 46, height: 46)
            .background(isPressed ? color.opacity(0.8) : color.opacity(0.15))
            .foregroundColor(.white)
            .clipShape(Circle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 1.0).onEnded { _ in
                    longPressAction?()
                    triggerPressAnimation()
                }
            )
            .simultaneousGesture(TapGesture().onEnded {
                action()
                triggerPressAnimation()
            })
    }
    
    func triggerPressAnimation() {
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isPressed = false }
    }
}
