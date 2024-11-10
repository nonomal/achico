# Achico - A Free MacOS Native File Compression App

A lightweight, native macOS app that intelligently compresses files while maintaining quality. Support for PDF, images, videos, and more! Simple, fast, and efficient!

![image](https://github.com/user-attachments/assets/4e10b8a7-decc-4e0b-8b56-f88198e75ec9)

## Features

### File Support
- **PDFs**: Smart compression while preserving readability
- **Images**: Support for JPEG, PNG, HEIC, TIFF, GIF, BMP, WebP, SVG, RAW, and ICO
- **Videos**: MP4, MOV, AVI, and other common formats
- **Audio**: M4V, WAV, MP3, AIFF
- **File Resizing**: Optionally resize images and videos while compressing

### Core Features
- **Multiple Input Methods**: Drag & drop or click to select files
- **Real-time Progress**: Watch your files being compressed with a clean progress indicator
- **Compression Stats**: See how much space you've saved instantly
- **Dark and Light modes**: Seamlessly integrates with your system preferences
- **Native Performance**: Built with SwiftUI for optimal macOS integration

### Compression Options
- **Quality Control**: Adjust compression levels to balance size and quality
- **Size Limits**: Set maximum dimensions for images and videos
- **Format Conversion**: Automatic conversion of less efficient formats
- **Metadata Handling**: Option to preserve or strip metadata

![compression-demo](https://github.com/user-attachments/assets/e494937d-7e52-4d6c-9046-d6b0d577c67e)


## 💻 Get Started

Download from the [releases](https://github.com/nuance-dev/Achico/releases/) page.

## ⚡️ How it Works

1. Drop or select your files
2. Adjust compression settings (optional)
3. Watch the magic happen
4. Get your compressed files
5. That's it!
6. Update, from v2 onwards you can resize your files!
![42630](https://github.com/user-attachments/assets/6def2137-fd12-4f7d-b59a-4476ae506331)


## 🛠 Technical Details

- Built natively for macOS using SwiftUI
- Uses specialized frameworks for each file type:
  - PDFKit for PDF compression
  - AVFoundation for video processing
  - Core Graphics for image optimization
- Efficient memory management for handling large files
- Clean, modern interface following Apple's design guidelines
- Parallel processing for better performance

## 🔮 Features Coming Soon

- Batch processing
- Folder monitoring
- Quick Look integration
- Custom presets for different use cases
- Additional file format support
- Advanced compression options
- Progress notifications

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. Clone the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please ensure your PR:
- Follows the existing code style
- Includes appropriate tests if applicable
- Updates documentation as needed

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- Report issues: [GitHub Issues](https://github.com/nuance-dev/Achico/issues)
- Follow updates: [@NuanceDev](https://twitter.com/Nuancedev)

## Requirements

- macOS 14.0 or later

## Supported File Formats

### Images
- JPEG/JPG
- PNG
- HEIC
- TIFF/TIF
- GIF (including animated)
- BMP
- WebP
- SVG
- RAW (CR2, NEF, ARW)
- ICO

### Videos
- MP4
- MOV
- AVI
- MPEG/MPG

### Documents
- PDF
