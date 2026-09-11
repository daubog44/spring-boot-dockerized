/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./event-ui/src/main/resources/templates/**/*.html"
  ],
  theme: {
    extend: {
      colors: {
        ember: {
          50: "#fff8f1",
          100: "#ffeddc",
          200: "#ffd4ac",
          500: "#cf5b32",
          700: "#8d321f",
          900: "#32140e"
        },
        moss: {
          100: "#dce7dd",
          500: "#4a6a57",
          700: "#284136"
        }
      },
      fontFamily: {
        display: ["Georgia", "Times New Roman", "serif"],
        body: ["ui-sans-serif", "system-ui", "sans-serif"]
      },
      boxShadow: {
        haze: "0 30px 80px rgba(50, 20, 14, 0.16)"
      }
    }
  }
};
