// Copyright (c) 2019 PaddlePaddle Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "pipeline.h"
#include <algorithm>
#include <cctype>
#include <iostream>
#include <regex>
#include <sstream>
#include <utility>

cv::Mat GetRotateCropImage(cv::Mat srcimage,
                           std::vector<std::vector<int>> box) {
  cv::Mat image;
  srcimage.copyTo(image);
  std::vector<std::vector<int>> points = box;

  int x_collect[4] = {box[0][0], box[1][0], box[2][0], box[3][0]};
  int y_collect[4] = {box[0][1], box[1][1], box[2][1], box[3][1]};
  int left = int(*std::min_element(x_collect, x_collect + 4));
  int right = int(*std::max_element(x_collect, x_collect + 4));
  int top = int(*std::min_element(y_collect, y_collect + 4));
  int bottom = int(*std::max_element(y_collect, y_collect + 4));

  left = std::max(0, std::min(left, image.cols - 1));
  right = std::max(0, std::min(right, image.cols));
  top = std::max(0, std::min(top, image.rows - 1));
  bottom = std::max(0, std::min(bottom, image.rows));
  if (right <= left + 1 || bottom <= top + 1) {
    return cv::Mat();
  }

  cv::Mat img_crop;
  image(cv::Rect(left, top, right - left, bottom - top)).copyTo(img_crop);

  for (int i = 0; i < points.size(); i++) {
    points[i][0] -= left;
    points[i][1] -= top;
  }

  int img_crop_width =
      static_cast<int>(sqrt(pow(points[0][0] - points[1][0], 2) +
                            pow(points[0][1] - points[1][1], 2)));
  int img_crop_height =
      static_cast<int>(sqrt(pow(points[0][0] - points[3][0], 2) +
                            pow(points[0][1] - points[3][1], 2)));
  if (img_crop_width <= 1 || img_crop_height <= 1) {
    return cv::Mat();
  }

  cv::Point2f pts_std[4];
  pts_std[0] = cv::Point2f(0., 0.);
  pts_std[1] = cv::Point2f(img_crop_width, 0.);
  pts_std[2] = cv::Point2f(img_crop_width, img_crop_height);
  pts_std[3] = cv::Point2f(0.f, img_crop_height);

  cv::Point2f pointsf[4];
  pointsf[0] = cv::Point2f(points[0][0], points[0][1]);
  pointsf[1] = cv::Point2f(points[1][0], points[1][1]);
  pointsf[2] = cv::Point2f(points[2][0], points[2][1]);
  pointsf[3] = cv::Point2f(points[3][0], points[3][1]);

  cv::Mat M = cv::getPerspectiveTransform(pointsf, pts_std);

  cv::Mat dst_img;
  cv::warpPerspective(img_crop, dst_img, M,
                      cv::Size(img_crop_width, img_crop_height),
                      cv::BORDER_REPLICATE);

  const float ratio = 1.5;
  if (static_cast<float>(dst_img.rows) >=
      static_cast<float>(dst_img.cols) * ratio) {
    cv::Mat srcCopy = cv::Mat(dst_img.rows, dst_img.cols, dst_img.depth());
    cv::transpose(dst_img, srcCopy);
    cv::flip(srcCopy, srcCopy, 0);
    return srcCopy;
  } else {
    return dst_img;
  }
}

std::vector<std::string> ReadDict(std::string path) {
  std::ifstream in(path);
  std::string filename;
  std::string line;
  std::vector<std::string> m_vec;
  if (in) {
    while (getline(in, line)) {
      m_vec.push_back(line);
    }
  } else {
    std::cout << "no such file" << std::endl;
  }
  return m_vec;
}

std::vector<std::string> split(const std::string &str,
                               const std::string &delim) {
  std::vector<std::string> res;
  if ("" == str)
    return res;
  char *strs = new char[str.length() + 1];
  std::strcpy(strs, str.c_str());

  char *d = new char[delim.length() + 1];
  std::strcpy(d, delim.c_str());

  char *p = std::strtok(strs, d);
  while (p) {
    std::string s = p;
    res.push_back(s);
    p = std::strtok(NULL, d);
  }

  return res;
}

std::map<std::string, double> LoadConfigTxt(std::string config_path) {
  auto config = ReadDict(config_path);

  std::map<std::string, double> dict;
  for (int i = 0; i < config.size(); i++) {
    std::vector<std::string> res = split(config[i], " ");
    dict[res[0]] = stod(res[1]);
  }
  return dict;
}

std::string EscapeJson(const std::string &value) {
  std::ostringstream escaped;
  for (char c : value) {
    switch (c) {
    case '"':
      escaped << "\\\"";
      break;
    case '\\':
      escaped << "\\\\";
      break;
    case '\b':
      escaped << "\\b";
      break;
    case '\f':
      escaped << "\\f";
      break;
    case '\n':
      escaped << "\\n";
      break;
    case '\r':
      escaped << "\\r";
      break;
    case '\t':
      escaped << "\\t";
      break;
    default:
      if (static_cast<unsigned char>(c) < 0x20) {
        escaped << "\\u00" << std::hex << std::uppercase
                << static_cast<int>(static_cast<unsigned char>(c));
      } else {
        escaped << c;
      }
    }
  }
  return escaped.str();
}

cv::Mat Visualization(cv::Mat srcimg,
                      std::vector<std::vector<std::vector<int>>> boxes,
                      std::string output_image_path) {
  cv::Mat img_vis;
  srcimg.copyTo(img_vis);
  for (int n = 0; n < boxes.size(); n++) {
    std::vector<cv::Point> points;
    for (int m = 0; m < boxes[n].size(); m++) {
      points.push_back(cv::Point(static_cast<int>(boxes[n][m][0]),
                                 static_cast<int>(boxes[n][m][1])));
    }
    const cv::Point *ppt[1] = {points.data()};
    int npt[] = {static_cast<int>(points.size())};
    cv::polylines(img_vis, ppt, npt, 1, 1, cv::Scalar(0, 255, 0), 2, 8, 0);
  }
  cv::imwrite(output_image_path, img_vis);
  return img_vis;
}

void Pipeline::VisualizeResults(std::vector<std::string> rec_text,
                                std::vector<float> rec_text_score,
                                cv::Mat *rgbaImage,
                                double *visualizeResultsTime) {
  auto t = GetCurrentTime();
  char text[255];
  cv::Scalar color = cv::Scalar(255, 255, 255);
  int font_face = cv::FONT_HERSHEY_PLAIN;
  double font_scale = 1.f;
  float thickness = 1;
  sprintf(text, "OCR results");
  cv::Size text_size =
      cv::getTextSize(text, font_face, font_scale, thickness, nullptr);
  text_size.height *= 1.25f;
  cv::Point2d offset(10, text_size.height + 15);
  cv::putText(*rgbaImage, text, offset, font_face, font_scale, color,
              thickness);

  for (int i = 0; i < rec_text.size(); i++) {
    LOGD("debug=== line %d %s, %f", i, rec_text[i].c_str(), rec_text_score[i]);
    sprintf(text, "line: %d %s  %f", i, rec_text[i].c_str(), rec_text_score[i]);
    offset.y += text_size.height;
    cv::putText(*rgbaImage, text, offset, font_face, font_scale, color,
                thickness);
  }
  *visualizeResultsTime = GetElapsedTime(t);
  LOGD("VisualizeResults costs %f ms", *visualizeResultsTime);
}

void Pipeline::VisualizeStatus(double readGLFBOTime, double writeGLTextureTime,
                               double predictTime,
                               std::vector<std::string> rec_text,
                               std::vector<float> rec_text_score,
                               double visualizeResultsTime,
                               cv::Mat *rgbaImage) {
  char text[255];
  cv::Scalar color = cv::Scalar(255, 255, 255);
  int font_face = cv::FONT_HERSHEY_PLAIN;
  double font_scale = 1.f;
  float thickness = 1;
  sprintf(text, "Read GLFBO time: %.1f ms", readGLFBOTime);
  cv::Size text_size =
      cv::getTextSize(text, font_face, font_scale, thickness, nullptr);
  text_size.height *= 1.25f;
  cv::Point2d offset(10, text_size.height + 15);
  cv::putText(*rgbaImage, text, offset, font_face, font_scale, color,
              thickness);
  sprintf(text, "Write GLTexture time: %.1f ms", writeGLTextureTime);
  offset.y += text_size.height;
  cv::putText(*rgbaImage, text, offset, font_face, font_scale, color,
              thickness);
  // predict time
  sprintf(text, "OCR all process time: %.1f ms", predictTime);
  offset.y += text_size.height;
  cv::putText(*rgbaImage, text, offset, font_face, font_scale, color,
              thickness);
  // Visualize results
  sprintf(text, "Visualize results time: %.1f ms", visualizeResultsTime);
  offset.y += text_size.height;
  cv::putText(*rgbaImage, text, offset, font_face, font_scale, color,
              thickness);
}

Pipeline::Pipeline(const std::string &detModelDir,
                   const std::string &clsModelDir,
                   const std::string &recModelDir,
                   const std::string &cPUPowerMode, const int cPUThreadNum,
                   const std::string &config_path,
                   const std::string &dict_path) {
  Config_ = LoadConfigTxt(config_path);
  charactor_dict_ = ReadDict(dict_path);
  charactor_dict_.insert(charactor_dict_.begin(), "#"); // blank char for ctc
  charactor_dict_.push_back(" ");

  detPredictor_.reset(
      new DetPredictor(detModelDir, cPUThreadNum, cPUPowerMode));
  recPredictor_.reset(
      new RecPredictor(recModelDir, cPUThreadNum, cPUPowerMode));

  if (int(Config_["use_direction_classify"]) >= 1) {
    clsPredictor_.reset(
        new ClsPredictor(clsModelDir, cPUThreadNum, cPUPowerMode));
  }
}

bool Pipeline::Process_val(int inTextureId, int outTextureId, int textureWidth,
                           int textureHeight, std::string savedImagePath) {
  double readGLFBOTime = 0, writeGLTextureTime = 0;
  double visualizeResultsTime = 0, predictTime = 0;
  int height = 448;
  int width = 448;
  cv::Mat rgbaImage;
  CreateRGBAImageFromGLFBOTexture(textureWidth, textureHeight, &rgbaImage,
                                  &readGLFBOTime);
  // change to 3-channel
  cv::Mat bgrImage;
  cv::cvtColor(rgbaImage, bgrImage, cv::COLOR_RGBA2BGR);
  cv::Mat bgrImage_resize;
  cv::resize(bgrImage, bgrImage_resize, cv::Size(width, height));

  int use_direction_classify = int(Config_["use_direction_classify"]);
  cv::Mat srcimg;
  bgrImage_resize.copyTo(srcimg);
  // Stage1: rec
  auto t = GetCurrentTime();
  // det predict
  auto boxes =
      detPredictor_->Predict(srcimg, Config_, nullptr, nullptr, nullptr);

  std::vector<float> mean = {0.5f, 0.5f, 0.5f};
  std::vector<float> scale = {1 / 0.5f, 1 / 0.5f, 1 / 0.5f};

  cv::Mat img;
  bgrImage_resize.copyTo(img);
  cv::Mat crop_img;

  std::vector<std::string> rec_text;
  std::vector<float> rec_text_score;
  LOGD("debug===boxes: %d", boxes.size());
  for (int i = boxes.size() - 1; i >= 0; i--) {
    crop_img = GetRotateCropImage(img, boxes[i]);
    if (crop_img.empty()) {
      continue;
    }
    if (use_direction_classify >= 1 && clsPredictor_ != nullptr) {
      crop_img =
          clsPredictor_->Predict(crop_img, nullptr, nullptr, nullptr, 0.9);
    }
    auto res = recPredictor_->Predict(crop_img, nullptr, nullptr, nullptr,
                                      charactor_dict_);
    rec_text.push_back(res.first);
    rec_text_score.push_back(res.second);
  }
  predictTime = GetElapsedTime(t);
  // visualization
  auto img_res = Visualization(bgrImage_resize, boxes, savedImagePath);
  cv::Mat img_vis;
  cv::resize(img_res, img_vis, cv::Size(textureWidth, textureHeight));
  cv::cvtColor(img_vis, img_vis, cv::COLOR_BGR2RGBA);
  // show ocr results on image
  //  VisualizeResults(rec_text, rec_text_score, &img_vis,
  //  &visualizeResultsTime);
  VisualizeStatus(readGLFBOTime, writeGLTextureTime, predictTime, rec_text,
                  rec_text_score, visualizeResultsTime, &img_vis);

  WriteRGBAImageBackToGLTexture(img_vis, outTextureId, &writeGLTextureTime);
  return true;
}

Pipeline::OcrRunResult
Pipeline::RunOcrData(cv::Mat &bgrImage, const std::string &visualizedPath,
                     const std::string &variant) {
  int use_direction_classify = int(Config_["use_direction_classify"]);
  OcrRunResult output;
  output.variant = variant;
  output.visualizedPath = visualizedPath;

  auto t = GetCurrentTime();
  cv::Mat srcimg;
  bgrImage.copyTo(srcimg);
  auto boxes =
      detPredictor_->Predict(srcimg, Config_, nullptr, nullptr, nullptr);

  cv::Mat crop_img;
  std::vector<std::string> rec_text;
  std::vector<float> rec_text_score;
  for (int i = static_cast<int>(boxes.size()) - 1; i >= 0; i--) {
    crop_img = GetRotateCropImage(srcimg, boxes[i]);
    if (crop_img.empty()) {
      continue;
    }
    if (use_direction_classify >= 1 && clsPredictor_ != nullptr) {
      crop_img =
          clsPredictor_->Predict(crop_img, nullptr, nullptr, nullptr, 0.9);
    }
    auto res = recPredictor_->Predict(crop_img, nullptr, nullptr, nullptr,
                                      charactor_dict_);
    output.texts.push_back(res.first);
    output.scores.push_back(res.second);
  }
  output.elapsedMs = GetElapsedTime(t);
  output.boxes = boxes;

  if (!visualizedPath.empty()) {
    Visualization(srcimg, boxes, visualizedPath);
  }
  return output;
}

std::string Pipeline::RunOcr(cv::Mat &bgrImage,
                             const std::string &visualizedPath,
                             double *predictTime) {
  auto result = RunOcrData(bgrImage, visualizedPath, "original");
  *predictTime = result.elapsedMs;
  return BuildOcrJson({result}, 0);
}

std::string Pipeline::BuildOcrJson(const std::vector<OcrRunResult> &runs,
                                   int bestIndex) {
  if (runs.empty()) {
    return "{\"text\":\"\",\"lines\":[],\"boxes\":0,\"boxPoints\":[],\"elapsedMs\":0}";
  }
  const auto &best = runs[bestIndex];

  std::vector<std::string> mergedTexts;
  std::vector<float> mergedScores;
  for (const auto &run : runs) {
    for (size_t i = 0; i < run.texts.size(); i++) {
      std::string text = run.texts[i];
      bool exists = false;
      for (const auto &known : mergedTexts) {
        if (known == text) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        mergedTexts.push_back(text);
        mergedScores.push_back(i < run.scores.size() ? run.scores[i] : 0);
      }
    }
  }

  double totalElapsed = 0;
  for (const auto &run : runs) {
    totalElapsed += run.elapsedMs;
  }

  std::ostringstream json;
  json << "{\"text\":\"";
  for (size_t i = 0; i < mergedTexts.size(); i++) {
    if (i > 0) {
      json << "\\n";
    }
    json << EscapeJson(mergedTexts[i]);
  }
  json << "\",\"lines\":[";
  for (size_t i = 0; i < mergedTexts.size(); i++) {
    if (i > 0) {
      json << ",";
    }
    json << "{\"text\":\"" << EscapeJson(mergedTexts[i]) << "\",\"score\":"
         << mergedScores[i] << "}";
  }
  json << "],\"boxes\":" << best.boxes.size() << ",\"boxPoints\":[";
  for (size_t i = 0; i < best.boxes.size(); i++) {
    if (i > 0) {
      json << ",";
    }
    json << "[";
    for (size_t j = 0; j < best.boxes[i].size(); j++) {
      if (j > 0) {
        json << ",";
      }
      json << "[" << best.boxes[i][j][0] << "," << best.boxes[i][j][1] << "]";
    }
    json << "]";
  }
  json << "],\"elapsedMs\":" << totalElapsed << ",\"bestVariant\":\""
       << EscapeJson(best.variant) << "\",\"visualizedPath\":\""
       << EscapeJson(best.visualizedPath) << "\",\"variants\":[";
  for (size_t i = 0; i < runs.size(); i++) {
    if (i > 0) {
      json << ",";
    }
    json << "{\"name\":\"" << EscapeJson(runs[i].variant) << "\",\"boxes\":"
         << runs[i].boxes.size() << ",\"lines\":" << runs[i].texts.size()
         << ",\"score\":" << ScoreOcrRun(runs[i]) << "}";
  }
  json << "]}";
  return json.str();
}

int Pipeline::ScoreOcrRun(const OcrRunResult &run) {
  int score = 0;
  for (const auto &text : run.texts) {
    std::string upper = text;
    std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);
    if (upper.find("PER") != std::string::npos) {
      score += 8;
    }
    if (upper.find("<<") != std::string::npos) {
      score += 8;
    }
    if (upper.find("APELL") != std::string::npos ||
        upper.find("NOMBRE") != std::string::npos ||
        upper.find("NAC") != std::string::npos) {
      score += 6;
    }
    if (std::regex_search(upper, std::regex("[0-9]{8}"))) {
      score += 10;
    }
    if (text.size() >= 3) {
      score += 1;
    }
  }
  score += static_cast<int>(run.boxes.size());
  return score;
}

cv::Mat Pipeline::AutoCropDni(const cv::Mat &bgrImage) {
  cv::Mat gray;
  cv::cvtColor(bgrImage, gray, cv::COLOR_BGR2GRAY);
  cv::GaussianBlur(gray, gray, cv::Size(5, 5), 0);

  cv::Mat darkMask;
  cv::threshold(gray, darkMask, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
  cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(19, 9));
  cv::morphologyEx(darkMask, darkMask, cv::MORPH_CLOSE, kernel);
  cv::dilate(darkMask, darkMask, kernel, cv::Point(-1, -1), 1);

  std::vector<std::vector<cv::Point>> contours;
  cv::findContours(darkMask, contours, cv::RETR_EXTERNAL,
                   cv::CHAIN_APPROX_SIMPLE);

  cv::Rect best;
  double bestScore = 0;
  const double imageArea = static_cast<double>(bgrImage.cols * bgrImage.rows);
  for (const auto &contour : contours) {
    cv::Rect rect = cv::boundingRect(contour);
    double area = static_cast<double>(rect.area());
    if (area < imageArea * 0.05) {
      continue;
    }
    double aspect = static_cast<double>(rect.width) / std::max(1, rect.height);
    if (aspect < 1.15 || aspect > 2.4) {
      continue;
    }
    double score = area * (1.0 - std::min(0.7, std::abs(aspect - 1.58)));
    if (score > bestScore) {
      bestScore = score;
      best = rect;
    }
  }

  if (bestScore <= 0) {
    return bgrImage.clone();
  }

  int padX = static_cast<int>(best.width * 0.04);
  int padY = static_cast<int>(best.height * 0.08);
  best.x = std::max(0, best.x - padX);
  best.y = std::max(0, best.y - padY);
  best.width = std::min(bgrImage.cols - best.x, best.width + padX * 2);
  best.height = std::min(bgrImage.rows - best.y, best.height + padY * 2);
  return bgrImage(best).clone();
}

cv::Mat Pipeline::RectifyDni(const cv::Mat &bgrImage) {
  cv::Mat gray;
  cv::cvtColor(bgrImage, gray, cv::COLOR_BGR2GRAY);
  cv::GaussianBlur(gray, gray, cv::Size(5, 5), 0);

  cv::Mat darkMask;
  cv::threshold(gray, darkMask, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
  cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(25, 13));
  cv::morphologyEx(darkMask, darkMask, cv::MORPH_CLOSE, kernel);
  cv::dilate(darkMask, darkMask, kernel, cv::Point(-1, -1), 1);

  std::vector<std::vector<cv::Point>> contours;
  cv::findContours(darkMask, contours, cv::RETR_EXTERNAL,
                   cv::CHAIN_APPROX_SIMPLE);

  cv::RotatedRect bestRect;
  double bestScore = 0;
  const double imageArea = static_cast<double>(bgrImage.cols * bgrImage.rows);
  for (const auto &contour : contours) {
    cv::RotatedRect rect = cv::minAreaRect(contour);
    double width = std::max(rect.size.width, rect.size.height);
    double height = std::min(rect.size.width, rect.size.height);
    if (width <= 1 || height <= 1) {
      continue;
    }
    double area = width * height;
    if (area < imageArea * 0.05) {
      continue;
    }
    double aspect = width / height;
    if (aspect < 1.2 || aspect > 2.4) {
      continue;
    }
    double score = area * (1.0 - std::min(0.8, std::abs(aspect - 1.58)));
    if (score > bestScore) {
      bestScore = score;
      bestRect = rect;
    }
  }

  if (bestScore <= 0) {
    return AutoCropDni(bgrImage);
  }

  cv::Point2f points[4];
  bestRect.points(points);
  std::vector<cv::Point2f> src(points, points + 4);
  std::sort(src.begin(), src.end(), [](const cv::Point2f &a,
                                       const cv::Point2f &b) {
    return (a.y + a.x) < (b.y + b.x);
  });

  cv::Point2f topLeft = src[0];
  cv::Point2f bottomRight = src[3];
  cv::Point2f topRight = src[1].x > src[2].x ? src[1] : src[2];
  cv::Point2f bottomLeft = src[1].x > src[2].x ? src[2] : src[1];

  double cardWidth =
      std::max(cv::norm(topRight - topLeft), cv::norm(bottomRight - bottomLeft));
  double cardHeight =
      std::max(cv::norm(bottomLeft - topLeft), cv::norm(bottomRight - topRight));
  if (cardWidth < cardHeight) {
    std::swap(cardWidth, cardHeight);
    std::swap(topRight, bottomLeft);
  }

  int outputWidth = std::max(900, static_cast<int>(cardWidth));
  int outputHeight = std::max(560, static_cast<int>(outputWidth / 1.586));
  std::vector<cv::Point2f> dst = {
      cv::Point2f(0, 0),
      cv::Point2f(static_cast<float>(outputWidth - 1), 0),
      cv::Point2f(static_cast<float>(outputWidth - 1),
                  static_cast<float>(outputHeight - 1)),
      cv::Point2f(0, static_cast<float>(outputHeight - 1)),
  };
  std::vector<cv::Point2f> ordered = {topLeft, topRight, bottomRight,
                                      bottomLeft};
  cv::Mat transform = cv::getPerspectiveTransform(ordered, dst);
  cv::Mat warped;
  cv::warpPerspective(bgrImage, warped, transform,
                      cv::Size(outputWidth, outputHeight),
                      cv::INTER_CUBIC, cv::BORDER_REPLICATE);
  return warped;
}

cv::Mat Pipeline::EnhanceDni(const cv::Mat &bgrImage, bool binary) {
  cv::Mat resized = bgrImage.clone();
  const int targetWidth = 1500;
  if (resized.cols < targetWidth) {
    double scale = static_cast<double>(targetWidth) / resized.cols;
    cv::resize(resized, resized, cv::Size(), scale, scale, cv::INTER_CUBIC);
  }

  cv::Mat lab;
  cv::cvtColor(resized, lab, cv::COLOR_BGR2Lab);
  std::vector<cv::Mat> channels;
  cv::split(lab, channels);
  auto clahe = cv::createCLAHE(3.0, cv::Size(8, 8));
  clahe->apply(channels[0], channels[0]);
  cv::merge(channels, lab);
  cv::Mat enhanced;
  cv::cvtColor(lab, enhanced, cv::COLOR_Lab2BGR);

  cv::Mat blur;
  cv::GaussianBlur(enhanced, blur, cv::Size(0, 0), 1.2);
  cv::addWeighted(enhanced, 1.55, blur, -0.55, 0, enhanced);

  if (!binary) {
    return enhanced;
  }

  cv::Mat gray;
  cv::cvtColor(enhanced, gray, cv::COLOR_BGR2GRAY);
  cv::adaptiveThreshold(gray, gray, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                        cv::THRESH_BINARY, 31, 9);
  cv::cvtColor(gray, enhanced, cv::COLOR_GRAY2BGR);
  return enhanced;
}

cv::Mat Pipeline::EnhanceDniFields(const cv::Mat &bgrImage) {
  cv::Mat resized = bgrImage.clone();
  const int targetWidth = 2200;
  if (resized.cols < targetWidth) {
    double scale = static_cast<double>(targetWidth) / resized.cols;
    cv::resize(resized, resized, cv::Size(), scale, scale, cv::INTER_CUBIC);
  }

  cv::Mat denoised;
  cv::bilateralFilter(resized, denoised, 7, 38, 38);

  cv::Mat lab;
  cv::cvtColor(denoised, lab, cv::COLOR_BGR2Lab);
  std::vector<cv::Mat> channels;
  cv::split(lab, channels);
  auto clahe = cv::createCLAHE(1.7, cv::Size(16, 16));
  clahe->apply(channels[0], channels[0]);
  cv::merge(channels, lab);

  cv::Mat enhanced;
  cv::cvtColor(lab, enhanced, cv::COLOR_Lab2BGR);
  cv::Mat blur;
  cv::GaussianBlur(enhanced, blur, cv::Size(0, 0), 0.85);
  cv::addWeighted(enhanced, 1.28, blur, -0.28, 0, enhanced);
  return enhanced;
}

cv::Mat Pipeline::CropRelative(const cv::Mat &image, double x, double y,
                               double width, double height) {
  int left = std::max(0, static_cast<int>(image.cols * x));
  int top = std::max(0, static_cast<int>(image.rows * y));
  int cropWidth = std::min(image.cols - left, static_cast<int>(image.cols * width));
  int cropHeight =
      std::min(image.rows - top, static_cast<int>(image.rows * height));
  if (cropWidth <= 1 || cropHeight <= 1) {
    return image.clone();
  }
  return image(cv::Rect(left, top, cropWidth, cropHeight)).clone();
}

std::vector<std::pair<std::string, cv::Mat>>
Pipeline::BuildDniPreprocessVariants(const cv::Mat &bgrImage) {
  std::vector<std::pair<std::string, cv::Mat>> variants;
  variants.push_back({"original", bgrImage.clone()});

  cv::Mat cropped = AutoCropDni(bgrImage);
  cv::Mat rectified = RectifyDni(bgrImage);
  variants.push_back({"crop", cropped});
  variants.push_back({"crop_enhanced", EnhanceDni(cropped, false)});
  variants.push_back({"crop_binary", EnhanceDni(cropped, true)});
  variants.push_back({"deskew", rectified});
  variants.push_back({"deskew_enhanced", EnhanceDni(rectified, false)});
  variants.push_back({"deskew_binary", EnhanceDni(rectified, true)});
  variants.push_back(
      {"deskew_fields_raw", CropRelative(rectified, 0.24, 0.08, 0.56, 0.46)});
  variants.push_back(
      {"deskew_fields_soft", EnhanceDniFields(CropRelative(rectified, 0.24, 0.08, 0.56, 0.46))});
  variants.push_back(
      {"deskew_names_soft", EnhanceDniFields(CropRelative(rectified, 0.28, 0.16, 0.46, 0.28))});
  variants.push_back(
      {"deskew_fields", EnhanceDni(CropRelative(rectified, 0.28, 0.08, 0.45, 0.58), false)});
  variants.push_back(
      {"deskew_mrz", EnhanceDni(CropRelative(rectified, 0.03, 0.70, 0.94, 0.28), false)});
  variants.push_back({"full_enhanced", EnhanceDni(bgrImage, false)});
  return variants;
}

std::string Pipeline::ProcessImage(const std::string &imagePath,
                                   const std::string &visualizedPath) {
  cv::Mat bgrImage = cv::imread(imagePath, cv::IMREAD_COLOR);
  if (bgrImage.empty()) {
    return "{\"text\":\"\",\"lines\":[],\"boxes\":0,\"error\":\"No se pudo leer la imagen\"}";
  }

  auto variants = BuildDniPreprocessVariants(bgrImage);
  std::vector<OcrRunResult> runs;
  int bestIndex = 0;
  int bestScore = -1;
  for (size_t i = 0; i < variants.size(); i++) {
    std::string variantVisualPath;
    if (!visualizedPath.empty()) {
      variantVisualPath = visualizedPath;
      if (variants.size() > 1) {
        size_t dot = variantVisualPath.find_last_of('.');
        if (dot == std::string::npos) {
          variantVisualPath += "_" + variants[i].first;
        } else {
          variantVisualPath = variantVisualPath.substr(0, dot) + "_" +
                              variants[i].first +
                              variantVisualPath.substr(dot);
        }
      }
    }
    auto run = RunOcrData(variants[i].second, variantVisualPath,
                          variants[i].first);
    int score = ScoreOcrRun(run);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = static_cast<int>(runs.size());
    }
    runs.push_back(run);
  }
  return BuildOcrJson(runs, bestIndex);
}

std::string Pipeline::ExportPreprocessVariants(const std::string &imagePath,
                                               const std::string &outputDir) {
  cv::Mat bgrImage = cv::imread(imagePath, cv::IMREAD_COLOR);
  if (bgrImage.empty()) {
    return "{\"variants\":[],\"error\":\"No se pudo leer la imagen\"}";
  }

  auto variants = BuildDniPreprocessVariants(bgrImage);
  std::ostringstream json;
  json << "{\"variants\":[";
  for (size_t i = 0; i < variants.size(); i++) {
    if (i > 0) {
      json << ",";
    }
    std::string filePath =
        outputDir + "/" + variants[i].first + ".jpg";
    bool ok = cv::imwrite(filePath, variants[i].second);
    json << "{\"name\":\"" << EscapeJson(variants[i].first)
         << "\",\"path\":\"" << EscapeJson(filePath)
         << "\",\"width\":" << variants[i].second.cols
         << ",\"height\":" << variants[i].second.rows
         << ",\"ok\":" << (ok ? "true" : "false") << "}";
  }
  json << "]}";
  return json.str();
}
