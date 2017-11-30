//
//  ViewController.swift
//  Let's Draw
//
//  Created by apple on 2017/11/8.
//  Copyright © 2017年 apple. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var DrawingBoardArea: DrawingBoard!
    
    // 所有笔刷
    var brushes = [
        "Pencil": PencilBrush(),
        "Eraser": EraserBrush(),
    ]
    var drawingColors = [
        "Red": UIColor.red,
        "White": UIColor.white,
    ]

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.DrawingBoardArea.brush = brushes["Pencil"]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    // MARK: Actions
    @IBAction func BrushButtonTapped(_ sender: UIButton) {
        if let brushName = sender.currentTitle {
            self.DrawingBoardArea.brush = brushes[brushName]
            if(brushName == "Eraser") {
                self.DrawingBoardArea.strokeWidth = 15
            } else {
                self.DrawingBoardArea.strokeWidth = 1
            }
        }
    }
    @IBAction func ColorButtonTapped(_ sender: UIButton) {
        if let colorName = sender.currentTitle, let color = drawingColors[colorName] {
            self.DrawingBoardArea.strokeColor = color
        }
    }
    
    
}
