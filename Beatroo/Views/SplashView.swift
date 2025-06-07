import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 80))
                    .foregroundColor(Color("BeatrooPink"))
                
                Text("Beatroo")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("BeatrooPink")))
                    .scaleEffect(1.2)
                    .padding(.top, 20)
            }
        }
    }
} 