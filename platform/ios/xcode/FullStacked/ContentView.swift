import SwiftUI
import WebKit
import JavaScriptCore

struct Project: Identifiable {
    var id: Int
    var js: JavaScript
}

class RunningProject: ObservableObject {
    @Published var project: Project?
    static var instance: RunningProject?
    static var id = 1
    
    init(){
        RunningProject.instance = self
    }
    
    func setRunningProject(js: JavaScript){
        self.project = Project(id: RunningProject.id, js: js)
        RunningProject.id += 1;
    }
}

struct ContentView: View {
    @ObservedObject private var runningProject = RunningProject()
    let mainjs: JavaScript;
    
    init(){
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true);
        let documentDir = paths.first!
        
        let assetdir = Bundle.main.bundlePath + "/dist/webview"
        
        let entrypointContents = FileManager.default.contents(atPath: Bundle.main.bundlePath + "/dist/api/index.js")!
        
        self.mainjs = JavaScript(
            fsdir: documentDir,
            assetdir: assetdir,
            entrypointContents: String(data: entrypointContents, encoding: .utf8)!
        )
        self.mainjs.privileged = true
        
        self.mainjs.ctx["jsDirectory"] = Bundle.main.bundlePath + "/js"
        
        let resolvePath: @convention (block) (String) -> String = { entrypoint in
            return documentDir + "/" + entrypoint
        }
        self.mainjs.ctx["resolvePath"] = resolvePath
        
        let run: @convention (block) (String, String, String) -> Void = { projectdir, assetdir, entrypoint in
            let entrypointPath = documentDir + "/" + entrypoint
            let entrypointPtr = UnsafeMutablePointer<Int8>(mutating: (entrypointPath as NSString).utf8String)
            let entrypointContents = String.init(cString: buildAPI(entrypointPtr)!, encoding: .utf8)!
            RunningProject.instance?.setRunningProject(js: JavaScript(
                fsdir: documentDir + "/" + projectdir,
                assetdir: assetdir,
                entrypointContents: entrypointContents
            ))
        }
        self.mainjs.ctx["run"] = run
    }

    
    var body: some View {
        ZStack {
            WebView(js: self.mainjs)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
                .ignoresSafeArea()
            if self.runningProject.project != nil {
                VStack {
                    Button("Close") {
                        self.runningProject.project = nil
                    }
                        .buttonStyle(.borderedProminent)
                    WebView(js: self.runningProject.project!.js)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        .ignoresSafeArea()
                }
                .background(Color.black)
            }
                
        }
    }
}

#Preview {
    ContentView()
}

class FullScreenWKWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: super.safeAreaInsets.top, left: 0, bottom: 0, right: 0)
    }
}

struct WebView: UIViewRepresentable {
    let js: JavaScript;
    
    init(js: JavaScript) {
        self.js = js
    }
    
    func makeUIView(context: Context) -> WKWebView  {
        let wkConfig = WKWebViewConfiguration()
        wkConfig.setURLSchemeHandler(RequestHandler(js: self.js),  forURLScheme: "fs")
        let wkWebView = FullScreenWKWebView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), configuration: wkConfig)
        
        let request = URLRequest(url: URL(string: "fs://localhost")!)
        wkWebView.load(request)
        return wkWebView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {

    }
}

class RequestHandler: NSObject, WKURLSchemeHandler {
    let js: JavaScript
    
    init(js: JavaScript) {
        self.js = js
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let request = urlSchemeTask.request
        
        let headers = request.allHTTPHeaderFields!
        let pathname = String(request.url!.pathComponents.joined(separator: "/").dropFirst())
        let body = request.httpBody
        
        let jsResponse = self.js.processRequest(headers: headers, pathname: pathname, body: body)
        
        
        let responseBody = jsResponse.data != nil
            ? jsResponse.data!
            : nil
        
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: responseBody != nil
                ? [
                    "Content-Type": jsResponse.mimeType,
                    "Content-Length": String(responseBody!.count)
                ]
            : nil
        )!
        
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(responseBody == nil ? Data() : responseBody!)
        urlSchemeTask.didFinish()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        
    }
}
