//
//  ViewController.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-18.
//

import UIKit

class ViewController: UIViewController {
    private let playerView: VideoPlayerView
    private let playButton = UIButton(type: .system)
    private let viewModel: VideoPlayerViewModel

    init(playerView: VideoPlayerView, viewModel: VideoPlayerViewModel) {
        self.playerView = playerView
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupViews()
        viewModel.onStateChange = {[weak self] in
            guard let self = self else {return}
            self.updateUI(for: $0)
        }
        viewModel.start()
    }

    
    private func setupViews(){
        playerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerView)
        
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setTitle("Play", for: .normal)
        playButton.setTitleColor(.black, for: .normal)
        playButton.backgroundColor = .white
        playButton.layer.cornerRadius = 9
        playButton.addTarget(self, action: #selector(didTapPlay), for: .touchUpInside)
        view.addSubview(playButton)
        
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: playButton.topAnchor),

            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            playButton.widthAnchor.constraint(equalToConstant: 120),
            playButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    @objc private func didTapPlay(){
        viewModel.togglePlay()
    }
    
    private func updateUI(for state: State){
        switch state {
        case .playing:
            playButton.setTitle("Stop", for: .normal)
        default:
            playButton.setTitle("Play", for: .normal)
        }
    }
}

