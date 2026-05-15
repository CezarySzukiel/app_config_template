import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: "0.0.0.0",
    allowedHosts: ["frontend"],
  },
  preview: {
    host: "0.0.0.0",
    allowedHosts: ["frontend"],
  },
});
