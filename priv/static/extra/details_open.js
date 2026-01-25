document.addEventListener("DOMContentLoaded", () => {
  const detailsElements = document.querySelectorAll("details");
  detailsElements.forEach((details) => {
    details.open = true;
  });
});
