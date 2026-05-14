const statusElement = document.querySelector<HTMLParagraphElement>("#status");

function renderStatus(): void {
  if (!statusElement) {
    return;
  }

  statusElement.textContent = "Frontend is running.";
}

renderStatus();
