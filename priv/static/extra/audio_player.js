document.addEventListener("DOMContentLoaded", () => {
  const audio = document.getElementById("audio");
  if (!audio) return;

  const btn = document.getElementById("play_pause");
  const vol = document.getElementById("volume");
  const volUp = document.getElementById("volume_up");
  const volDown = document.getElementById("volume_down");

  audio.volume = 0.3;
  vol.textContent = " " + Math.ceil(audio.volume * 100) + "% ";

  btn.addEventListener("click", () => {
    if (audio.paused) {
      audio.play();
      btn.textContent = "Pause";
    } else {
      audio.pause();
      btn.textContent = "Play";
    }
  });

  volUp.addEventListener("click", () => {
    audio.volume = Math.min(1, audio.volume + 0.05);
    vol.textContent = " " + Math.ceil(audio.volume * 100) + "% ";
  });

  volDown.addEventListener("click", () => {
    audio.volume = Math.max(0, audio.volume - 0.05);
    vol.textContent = " " + Math.ceil(audio.volume * 100) + "% ";
  });
});
