class Nonsleep < Formula
  desc "Prevent macOS from sleeping when the lid is closed"
  homepage "https://github.com/danwoo/nonsleep"
  url "https://github.com/danwoo/nonsleep/archive/refs/tags/v1.0.0.tar.gz"
  sha256 ""
  license "MIT"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
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
