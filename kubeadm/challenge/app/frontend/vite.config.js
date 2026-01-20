import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    server: {
        host: true, // Pour écouter sur 0.0.0.0 dans Docker
        proxy: {
            '/api': {
                target: 'http://portfolio-backend-service', // Utile en dev local si on a le VPN, ignoré en prod Nginx
                changeOrigin: true,
                rewrite: (path) => path.replace(/^\/api/, '')
            }
        }
    }
})
