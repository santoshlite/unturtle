import SwiftUI

struct Feedback: View {
    let imageName: String
    let feedback: String
    
    var body: some View {
        
        VStack{
            Image(imageName)
                .resizable().frame(minWidth: 35, maxWidth: 75, minHeight: 35, maxHeight: 75, alignment: .topTrailing).padding(.bottom, 10)
            Text(feedback)
                .padding()
                .background(.secondary)
                .foregroundColor(.white)
                .cornerRadius(10) 
        }.padding(20)
    }
}
