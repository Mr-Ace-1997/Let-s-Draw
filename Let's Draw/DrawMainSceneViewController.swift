//
//  DrawMainSceneViewController.swift
//  Let's Draw
//
//  Created by apple on 2017/11/8.
//  Copyright © 2017年 apple. All rights reserved.
//

import UIKit
import os.log
import Alamofire
import Starscream

class DrawMainSceneViewController: UIViewController, WebSocketDelegate, SendDrawingBoardDelegate {

    // MARK: Properties
    
    @IBOutlet weak var DrawingBoardArea: DrawingBoard!

    var me: User?
    var hint: String!
    var keyWord: String!
    
    var socket: WebSocket!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.DrawingBoardArea.brush = DrawingTools.brushes["Pencil"]
        navigationItem.title = "题目：" + keyWord!
        
        // web socket
        socket.delegate = self
        
        self.DrawingBoardArea.sendDrawingBoardDelegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    // MARK: Actions

    @IBAction func endGameButtonPressed(_ sender: UIBarButtonItem) {
        // 按下结束游戏按钮后，弹出对话框询问是否确认结束
        let endGameAlertController = UIAlertController(title: "结束游戏", message: "确定要结束本局游戏吗？", preferredStyle: UIAlertControllerStyle.alert)
        let cancelAction = UIAlertAction(title: "再玩一会儿", style: UIAlertActionStyle.cancel, handler: nil)
        let confirmAction = UIAlertAction(title: "确定", style: UIAlertActionStyle.default){
            (UIAlertAction) in
            self.endGame()
        }
        endGameAlertController.addAction(cancelAction)
        endGameAlertController.addAction(confirmAction)
        self.present(endGameAlertController, animated: true, completion: nil)
    }
    
    @IBAction func BrushButtonTapped(_ sender: UIButton) {
        if let brushName = sender.currentTitle {
            self.DrawingBoardArea.brush = DrawingTools.brushes[brushName]
            if(brushName == "Eraser") {
                self.DrawingBoardArea.strokeWidth = 15
            } else {
                self.DrawingBoardArea.strokeWidth = 1
            }
        }
    }
    @IBAction func ColorButtonTapped(_ sender: UIButton) {
        if let colorName = sender.currentTitle, let color = DrawingTools.drawingColors[colorName] {
            self.DrawingBoardArea.strokeColor = color
            self.DrawingBoardArea.colorName = colorName
        }
    }
    
    // MARK: Private methods
    
    private func endGame() {
        // web socket
        let parameters:[String: Any] = [
            "type": "changeGameState",
            "playerId": self.me!.id,
            "roomId": self.me!.roomId!,
            "newGameState": "ended"
        ]
        let data = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        socket.write(data: data!)
        
        // Connect the server
        let urlPath: String = "http://localhost:3000/tasks/endGameInRoom?roomId=\(me!.roomId!)"
        let params = NSMutableDictionary()
        var jsonData:Data? = nil
        do {
            jsonData  = try JSONSerialization.data(withJSONObject: params, options:JSONSerialization.WritingOptions.prettyPrinted)
        } catch {
            fatalError("Wrong post params when trying to end game.")
        }
        
        // Use semaphore to send Synchronous request
        let semaphore = DispatchSemaphore(value: 0)
        
        ServerConnectionDelegator.httpPost(urlPath: urlPath, httpBody: jsonData!) {
            (data, error) -> Void in
            if error != nil {
                print(error!)
            } else {
                if let ok = (data as! [NSDictionary])[0]["ok"] {
                    print("endGame: ok : \(ok)")
                } else {
                    os_log("endGame: unexpected response from server.", log: OSLog.default, type: .debug)
                }
            }
            
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    public func sendDrawingBoard() {
        
        //let semaphore = DispatchSemaphore(value: 0)
            
        let parameters:[String: Any] = [
            "type": "sendDrawingBoard",
            "brushState": self.DrawingBoardArea.drawingState.toString(),
            "brushPositionX": self.DrawingBoardArea.brushPositionX,
            "brushPositionY": self.DrawingBoardArea.brushPositionY,
            "brushKind": self.DrawingBoardArea.brush?.brushName() ?? "default",
            "brushColor": self.DrawingBoardArea.colorName
        ]
        let data = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        socket.write(data: data!)
        
        /*
            Alamofire.request("http://localhost:3000/tasks/sendDrawingBoard?roomId=\(me!.roomId!)", method: .post, parameters: parameters).responseJSON { response in
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
         */
        
        
    }
    
    // MARK: - WebSocketDelegate
    
    func websocketDidConnect(socket: WebSocketClient) {
        
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        // 1
        guard let data = text.data(using: .utf16),
            let jsonData = try? JSONSerialization.jsonObject(with: data),
            let jsonDict = jsonData as? [String: Any],
            let messageType = jsonDict["type"] as? String
            else {
                return
        }
        
        // 2
        switch messageType {
        case "changeGameState":
            if let newGameState = jsonDict["newGameState"] as? String {
                switch newGameState {
                    /*
                     0: ended
                     1: readyToBegin
                     2: onGoing
                     */
                case "ended":
                    performSegue(withIdentifier: "unwindToPrepareScene", sender: self)
                    //print("game is ended")
                //self.performSegue(withIdentifier: "WaitingForGameToStart", sender: self)
                default:
                    print("newGameState should be \(newGameState)")
                }
            }
        default:
            os_log("Unknown message type.", log: OSLog.default, type: .debug)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        
    }
    
    
}

