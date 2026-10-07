import SwiftUI

struct ContentView: View {
    // ==========================================
    // المتغيرات (State) المطابقة للـ JavaScript
    // ==========================================
    @State private var currentTV = "sony"
    @State private var isVolumeMode = false
    
    // متغيرات اللمس
    @State private var touchPoint: CGPoint? = nil
    @State private var isTap = true
    @State private var hasLongPressed = false
    @State private var lastDragLocation: CGPoint = .zero
    
    // متغيرات المؤقتات والتحكم بالسرعة
    @State private var lastCommandTime: Date = Date.distantPast
    private let throttleDelay: TimeInterval = 0.1 // 100ms
    private let swipeThreshold: CGFloat = 20.0
    
    // خادمك (ضع الـ IP والـ Port الخاص بسيرفر Termux هنا)
    let serverBaseURL = "http://192.168.X.X:PORT"

    var body: some View {
        ZStack {
            // 1. الخلفية السوداء بالكامل (بديل body background)
            Color.black
                .ignoresSafeArea()
            
            // 2. منطقة اللمس الشفافة (بديل #area)
            Color.white.opacity(0.001) // يجب أن يكون له لون خفيف جداً ليلتقط اللمس
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleTouchMove(value: value)
                        }
                        .onEnded { value in
                            handleTouchEnd(value: value)
                        }
                )
            
            // 3. النقطة المرئية تحت الإصبع (بديل #touch-point)
            if let tp = touchPoint {
                Circle()
                    .fill(hasLongPressed ? Color.red.opacity(0.8) : Color.white.opacity(0.5))
                    .frame(width: 40, height: 40)
                    .shadow(color: .white.opacity(0.3), radius: 7)
                    .position(tp)
                    .allowsHitTesting(false) // لكي لا تمنع اللمس عما تحتها
            }
            
            // 4. طبقة الأزرار (بديل #ui-layer)
            buttonsLayer
        }
        // جعل شريط الحالة (الوقت والبطارية) أبيض ليناسب الخلفية السوداء (للآيفون)
        .preferredColorScheme(.dark)
    }
    
    // ==========================================
    // واجهة الأزرار
    // ==========================================
    var buttonsLayer: some View {
        ZStack {
            // زر التبديل بين التلفازين (أعلى الوسط)
            Button(action: {
                currentTV = (currentTV == "sony") ? "samsung" : "sony"
            }) {
                Text(currentTV == "sony" ? "📺 SONY" : "📺 SAMSUNG")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 42)
                    .background(currentTV == "sony" ? Color.orange.opacity(0.4) : Color.blue.opacity(0.4))
                    .cornerRadius(21)
            }
            .position(x: UIScreen.main.bounds.width / 2, y: 40)
            
            // زر Home (أعلى اليسار)
            ActionButton(icon: "🏠", color: .white) {
                safeSendCommand("home")
            } longPressAction: {
                safeSendCommand("power")
            }
            .position(x: 42, y: 42)
            
            // زر Input (أسفل اليسار)
            ActionButton(icon: "📺", color: .white) {
                safeSendCommand("input")
            }
            .position(x: 42, y: UIScreen.main.bounds.height - 42)
            
            // زر Mode (أعلى اليمين)
            ActionButton(icon: isVolumeMode ? "🔊" : "🕹️", color: isVolumeMode ? .green : .white) {
                isVolumeMode.toggle()
            }
            .position(x: UIScreen.main.bounds.width - 42, y: 42)
            
            // زر Mute (أسفل اليمين)
            ActionButton(icon: "🔇", color: .white) {
                safeSendCommand("mute")
            }
            .position(x: UIScreen.main.bounds.width - 42, y: UIScreen.main.bounds.height - 42)
        }
    }
    
    // ==========================================
    // منطق اللمس والسحب (بديل touchstart و touchmove)
    // ==========================================
    func handleTouchMove(value: DragGesture.Value) {
        let currentX = value.location.x
        let currentY = value.location.y
        
        // إذا كانت هذه بداية اللمسة
        if touchPoint == nil {
            isTap = true
            hasLongPressed = false
            lastDragLocation = value.location
            
            // تفعيل مؤقت الضغطة المطولة (Long Press = Back)
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
        
        // إلغاء فكرة أنها نقرة إذا تحرك الإصبع مسافة معينة
        if hypot(dx, dy) > 10 {
            isTap = false
        }
        
        // فحص الاتجاهات بناءً على حساسية السحب
        if abs(dx) > swipeThreshold || abs(dy) > swipeThreshold {
            var cmdToSend: String? = nil
            
            if abs(dx) > abs(dy) { // حركة أفقية
                if !isVolumeMode {
                    cmdToSend = dx > 0 ? "right" : "left"
                }
            } else { // حركة عمودية
                if dy > 0 {
                    cmdToSend = isVolumeMode ? "voldown" : "down"
                } else {
                    cmdToSend = isVolumeMode ? "volup" : "up"
                }
            }
            
            if let cmd = cmdToSend {
                safeSendCommand(cmd)
                // النقطة الحالية تصبح المرجع الجديد (للسحب المستمر)
                lastDragLocation = value.location
            }
        }
    }
    
    func handleTouchEnd(value: DragGesture.Value) {
        if isTap && !hasLongPressed {
            safeSendCommand("enter")
        }
        // إخفاء النقطة
        touchPoint = nil
    }
    
    // ==========================================
    // دالة الإرسال الآمن للسيرفر (بديل fetch)
    // ==========================================
    func safeSendCommand(_ cmd: String) {
        let now = Date()
        if now.timeIntervalSince(lastCommandTime) >= throttleDelay {
            lastCommandTime = now
            
            guard let url = URL(string: "\(serverBaseURL)/\(currentTV)/\(cmd)") else { return }
            
            // إرسال الـ Request في الخلفية بدون انتظار الرد
            URLSession.shared.dataTask(with: url).resume()
            
            // طباعة للتأكد من عمل الكود (تظهر في الكونسول)
            print("Sent: \(currentTV)/\(cmd)")
        }
    }
}

// ==========================================
// مكون (Component) مخصص لرسم الأزرار الدائرية
// ==========================================
struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    var longPressAction: (() -> Void)? = nil
    
    @State private var isPressed = false
    
    var body: some View {
        Text(icon)
            .font(.system(size: 26))
            .frame(width: 60, height: 60)
            .background(isPressed ? color.opacity(0.8) : color.opacity(0.15))
            .foregroundColor(.white)
            .clipShape(Circle())
            // دمج الضغطة العادية مع الضغطة المطولة
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 1.0)
                    .onEnded { _ in
                        if let longPress = longPressAction {
                            longPress()
                            triggerPressAnimation()
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        action()
                        triggerPressAnimation()
                    }
            )
    }
    
    func triggerPressAnimation() {
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPressed = false
        }
    }
}
