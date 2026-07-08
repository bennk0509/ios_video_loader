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
    private let pauseButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
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
        viewModel.onPreferredTransform = {[weak self] transform in
            self?.playerView.applyPreferredTransform(transform)
        }
        updateUI(for: viewModel.state)
    }


    private func setupViews(){
        playerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerView)

        configure(playButton, title: "Play", action: #selector(didTapPlay))
        configure(pauseButton, title: "Pause", action: #selector(didTapPause))
        configure(stopButton, title: "Stop", action: #selector(didTapStop))

        let controls = UIStackView(arrangedSubviews: [playButton, pauseButton, stopButton])
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.axis = .horizontal
        controls.distribution = .fillEqually
        controls.spacing = 12
        view.addSubview(controls)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: controls.topAnchor),

            controls.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            controls.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            controls.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func configure(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 9
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func didTapPlay(){
        // Play khi đang pause = resume; các trạng thái khác = phát từ đầu.
        if case .paused = viewModel.state {
            viewModel.resume()
        } else {
            viewModel.play()
        }
    }

    @objc private func didTapPause(){
        viewModel.pause()
    }

    @objc private func didTapStop(){
        viewModel.stop()
    }

    private func updateUI(for state: State){
        switch state {
        case .playing:
            setEnabled(play: false, pause: true, stop: true)
        case .paused:
            setEnabled(play: true, pause: false, stop: true)
        case .idle, .stopped, .finished:
            setEnabled(play: true, pause: false, stop: false)
        case .failed:
            setEnabled(play: true, pause: false, stop: false)
        }
    }

    private func setEnabled(play: Bool, pause: Bool, stop: Bool) {
        apply(play, to: playButton)
        apply(pause, to: pauseButton)
        apply(stop, to: stopButton)
    }

    private func apply(_ enabled: Bool, to button: UIButton) {
        button.isEnabled = enabled
        button.alpha = enabled ? 1.0 : 0.4
    }
}
