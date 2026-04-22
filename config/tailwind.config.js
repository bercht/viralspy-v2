// config/tailwind.config.js
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    './app/components/**/*.{erb,haml,html,slim,rb}'
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          primary: '#0070cc',
          'primary-hover': '#005fa8',
          accent: '#1eaedb'
        },
        surface: {
          canvas: '#ffffff',
          base: '#f5f7fa',
          raised: '#ffffff',
          dark: '#0a0a0b',
          'dark-raised': '#1a1a1d'
        },
        border: {
          subtle: '#e5e7eb',
          default: '#cccccc',
          strong: '#6b6b6b'
        },
        text: {
          display: '#000000',
          body: '#1f1f1f',
          muted: '#6b6b6b',
          subtle: '#9ca3af',
          'on-dark': '#ffffff',
          'on-dark-muted': '#cccccc'
        },
        semantic: {
          success: '#059669',
          'success-bg': '#ecfdf5',
          danger: '#c81b3a',
          'danger-bg': '#fef2f2',
          warning: '#d97706',
          'warning-bg': '#fffbeb',
          info: '#0070cc',
          'info-bg': '#eff6ff',
          neutral: '#6b6b6b',
          'neutral-bg': '#f3f4f6'
        }
      },
      fontFamily: {
        sans: ['Outfit', ...defaultTheme.fontFamily.sans],
        display: ['Outfit', ...defaultTheme.fontFamily.sans]
      },
      fontSize: {
        'display-xl': ['3rem', { lineHeight: '1.2', letterSpacing: '-0.02em', fontWeight: '300' }],
        'display-lg': ['2.25rem', { lineHeight: '1.25', letterSpacing: '-0.01em', fontWeight: '300' }],
        'display': ['1.75rem', { lineHeight: '1.3', letterSpacing: '0', fontWeight: '300' }],
        'heading': ['1.25rem', { lineHeight: '1.35', fontWeight: '600' }],
        'heading-sm': ['1rem', { lineHeight: '1.4', fontWeight: '600' }],
        'body': ['0.9375rem', { lineHeight: '1.55' }],
        'body-sm': ['0.875rem', { lineHeight: '1.5' }],
        'caption': ['0.75rem', { lineHeight: '1.4', letterSpacing: '0.01em', fontWeight: '500' }],
        'button': ['0.875rem', { lineHeight: '1.25', letterSpacing: '0.02em', fontWeight: '500' }]
      },
      borderRadius: {
        'input': '3px',
        'card': '12px',
        'feature': '24px',
        'pill': '999px'
      },
      boxShadow: {
        'feather': '0 1px 2px 0 rgba(0, 0, 0, 0.04)',
        'card': '0 1px 3px 0 rgba(0, 0, 0, 0.06), 0 1px 2px 0 rgba(0, 0, 0, 0.04)',
        'raised': '0 5px 9px 0 rgba(0, 0, 0, 0.08)',
        'focus': '0 0 0 2px rgba(0, 112, 204, 0.25)',
        'focus-strong': '0 0 0 3px rgba(0, 112, 204, 0.35)'
      }
    }
  },
  plugins: [
    require('@tailwindcss/forms')
  ]
}
