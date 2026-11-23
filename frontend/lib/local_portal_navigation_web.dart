// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void navigateToLocalPortal(String url) {
  html.window.location.assign(url);
}

bool openInstitutionSite(String url) {
  html.window.open(url, '_blank', 'noopener,noreferrer');
  return true;
}
