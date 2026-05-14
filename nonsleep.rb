class Nonsleep < Formula
  desc "Prevent macOS from sleeping when the lid is closed"
  homepage "https://github.com/3289david/nonsleep"
  url "https://github.com/3289david/nonsleep/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "d99da455b1c9de5c0a224b7d7669fb03a3f43c8a31106e1ae74d894be6a195fe"
  license "MIT"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox",
           "--arch", "arm64", "--arch", "x86_64"
    bin.install ".build/release/nonsleep"
    bin.install ".build/release/nonsleepd"
  end

  service do
    run [opt_bin/"nonsleepd"]
    keep_alive true
    log_path var/"log/nonsleep.log"
    error_log_path var/"log/nonsleep.err"
  end

  test do
    assert_match "NonSleep", shell_output("#{bin}/nonsleep --help")
  end
end
