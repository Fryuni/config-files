{
  defaultBrowser,
  defaultVideo,
  defaultAudio ? defaultVideo,
}: {
  enable = true;
  associations.added = {
    "image/png" = "org.xfce.ristretto.desktop";
    "image/jpeg" = "org.xfce.ristretto.desktop";
    "applications/zip" = "xarchiver.desktop";
    "text/plain" = "org.xfce.mousepad.desktop";
    "x-scheme-handler/http" = defaultBrowser;
    "x-scheme-handler/https" = defaultBrowser;
  };

  defaultApplications = {
    "image/png" = "org.xfce.ristretto.desktop";
    "image/jpeg" = "org.xfce.ristretto.desktop";
    "applications/zip" = "xarchiver.desktop";
    "application/pdf" = "okularApplication_pdf.desktop";
    "application/ogg" = defaultAudio;
    "application/x-ogg" = defaultAudio;
    "application/mxf" = "mpv.desktop";
    "application/sdp" = "mpv.desktop";
    "application/smil" = "mpv.desktop";
    "application/x-smil" = "mpv.desktop";
    "application/streamingmedia" = defaultVideo;
    "application/x-streamingmedia" = defaultVideo;
    "application/vnd.rn-realmedia" = defaultVideo;
    "application/vnd.rn-realmedia-vbr" = defaultVideo;
    "audio/aac" = defaultAudio;
    "audio/x-aac" = defaultAudio;
    "audio/vnd.dolby.heaac.1" = defaultAudio;
    "audio/vnd.dolby.heaac.2" = defaultAudio;
    "audio/aiff" = defaultAudio;
    "audio/x-aiff" = defaultAudio;
    "audio/m4a" = defaultAudio;
    "audio/x-m4a" = defaultAudio;
    "application/x-extension-m4a" = "mpv.desktop";
    "audio/mp1" = defaultAudio;
    "audio/x-mp1" = defaultAudio;
    "audio/mp2" = defaultAudio;
    "audio/x-mp2" = defaultAudio;
    "audio/mp3" = defaultAudio;
    "audio/x-mp3" = defaultAudio;
    "audio/mpeg" = defaultAudio;
    "audio/mpeg2" = defaultAudio;
    "audio/mpeg3" = defaultAudio;
    "audio/mpegurl" = defaultAudio;
    "audio/x-mpegurl" = defaultAudio;
    "audio/mpg" = defaultAudio;
    "audio/x-mpg" = defaultAudio;
    "audio/rn-mpeg" = defaultAudio;
    "audio/musepack" = defaultAudio;
    "audio/x-musepack" = defaultAudio;
    "audio/ogg" = defaultAudio;
    "audio/scpls" = defaultAudio;
    "audio/x-scpls" = defaultAudio;
    "audio/vnd.rn-realaudio" = defaultAudio;
    "audio/wav" = defaultAudio;
    "audio/x-pn-wav" = defaultAudio;
    "audio/x-pn-windows-pcm" = defaultAudio;
    "audio/x-realaudio" = defaultAudio;
    "audio/x-pn-realaudio" = defaultAudio;
    "audio/x-ms-wma" = defaultAudio;
    "audio/x-pls" = defaultAudio;
    "audio/x-wav" = defaultAudio;
    "video/mpeg" = defaultVideo;
    "video/x-mpeg2" = defaultVideo;
    "video/x-mpeg3" = defaultVideo;
    "video/mp4v-es" = defaultVideo;
    "video/x-m4v" = defaultVideo;
    "video/mp4" = defaultVideo;
    "application/x-extension-mp4" = "mpv.desktop";
    "video/divx" = defaultVideo;
    "video/vnd.divx" = defaultVideo;
    "video/msvideo" = defaultVideo;
    "video/x-msvideo" = defaultVideo;
    "video/ogg" = defaultVideo;
    "video/quicktime" = defaultVideo;
    "video/vnd.rn-realvideo" = defaultVideo;
    "video/x-ms-afs" = defaultVideo;
    "video/x-ms-asf" = defaultVideo;
    "audio/x-ms-asf" = defaultAudio;
    "application/vnd.ms-asf" = "mpv.desktop";
    "video/x-ms-wmv" = defaultVideo;
    "video/x-ms-wmx" = defaultVideo;
    "video/x-ms-wvxvideo" = defaultVideo;
    "video/x-avi" = defaultVideo;
    "video/avi" = defaultVideo;
    "video/x-flic" = defaultVideo;
    "video/fli" = defaultVideo;
    "video/x-flc" = defaultVideo;
    "video/flv" = defaultVideo;
    "video/x-flv" = defaultVideo;
    "video/x-theora" = defaultVideo;
    "video/x-theora+ogg" = defaultVideo;
    "video/x-matroska" = defaultVideo;
    "video/mkv" = defaultVideo;
    "audio/x-matroska" = defaultAudio;
    "application/x-matroska" = "mpv.desktop";
    "video/webm" = defaultVideo;
    "audio/webm" = defaultAudio;
    "audio/vorbis" = defaultAudio;
    "audio/x-vorbis" = defaultAudio;
    "audio/x-vorbis+ogg" = defaultAudio;
    "video/x-ogm" = defaultVideo;
    "video/x-ogm+ogg" = defaultVideo;
    "application/x-ogm" = "mpv.desktop";
    "application/x-ogm-audio" = "mpv.desktop";
    "application/x-ogm-video" = "mpv.desktop";
    "application/x-shorten" = "mpv.desktop";
    "audio/x-shorten" = defaultAudio;
    "audio/x-ape" = defaultAudio;
    "audio/x-wavpack" = defaultAudio;
    "audio/x-tta" = defaultAudio;
    "audio/AMR" = defaultAudio;
    "audio/ac3" = defaultAudio;
    "audio/eac3" = defaultAudio;
    "audio/amr-wb" = defaultAudio;
    "video/mp2t" = defaultVideo;
    "audio/flac" = defaultAudio;
    "audio/mp4" = defaultAudio;
    "application/x-mpegurl" = "mpv.desktop";
    "video/vnd.mpegurl" = defaultVideo;
    "application/vnd.apple.mpegurl" = "mpv.desktop";
    "audio/x-pn-au" = defaultAudio;
    "video/3gp" = defaultVideo;
    "video/3gpp" = defaultVideo;
    "video/3gpp2" = defaultVideo;
    "audio/3gpp" = defaultAudio;
    "audio/3gpp2" = defaultAudio;
    "video/dv" = defaultVideo;
    "audio/dv" = defaultAudio;
    "audio/opus" = defaultAudio;
    "audio/vnd.dts" = defaultAudio;
    "audio/vnd.dts.hd" = defaultAudio;
    "audio/x-adpcm" = defaultAudio;
    "application/x-cue" = "mpv.desktop";
    "audio/m3u" = defaultAudio;
    "x-scheme-handler/http" = defaultBrowser;
    "x-scheme-handler/https" = defaultBrowser;
    "x-scheme-handler/chrome" = defaultBrowser;
    "text/html" = defaultBrowser;
    "application/x-extension-htm" = defaultBrowser;
    "application/x-extension-html" = defaultBrowser;
    "application/x-extension-shtml" = defaultBrowser;
    "application/xhtml+xml" = defaultBrowser;
    "application/x-extension-xhtml" = defaultBrowser;
    "application/x-extension-xht" = defaultBrowser;
  };
}
