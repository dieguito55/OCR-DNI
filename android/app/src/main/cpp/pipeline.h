// Copyright (c) 2020 PaddlePaddle Authors. All Rights Reserved.
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

#pragma once
#include "cls_process.h"
#include "det_process.h"
#include "paddle_api.h"
#include "rec_process.h"
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <opencv2/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <string>
#include <vector>
using namespace paddle::lite_api; // NOLINT

class Pipeline {
public:
  Pipeline(const std::string &detModelDir, const std::string &clsModelDir,
           const std::string &recModelDir, const std::string &cPUPowerMode,
           const int cPUThreadNum, const std::string &config_path,
           const std::string &dict_path);

  bool Process_val(int inTextureId, int outTextureId, int textureWidth,
                   int textureHeight, std::string savedImagePath);

  std::string ProcessImage(const std::string &imagePath,
                           const std::string &visualizedPath);
  std::string ExportPreprocessVariants(const std::string &imagePath,
                                       const std::string &outputDir);

private:
  struct OcrRunResult {
    std::string variant;
    std::string visualizedPath;
    std::vector<std::string> texts;
    std::vector<float> scores;
    std::vector<std::vector<std::vector<int>>> boxes;
    double elapsedMs = 0;
  };

  // Read pixels from FBO texture to CV image
  void CreateRGBAImageFromGLFBOTexture(int textureWidth, int textureHeight,
                                       cv::Mat *rgbaImage,
                                       double *readGLFBOTime) {
    auto t = GetCurrentTime();
    rgbaImage->create(textureHeight, textureWidth, CV_8UC4);
    glReadPixels(0, 0, textureWidth, textureHeight, GL_RGBA, GL_UNSIGNED_BYTE,
                 rgbaImage->data);
    *readGLFBOTime = GetElapsedTime(t);
    LOGD("Read from FBO texture costs %f ms", *readGLFBOTime);
  }
  // Write back to texture2D
  void WriteRGBAImageBackToGLTexture(const cv::Mat &rgbaImage, int textureId,
                                     double *writeGLTextureTime) {
    auto t = GetCurrentTime();
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureId);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, rgbaImage.cols, rgbaImage.rows,
                    GL_RGBA, GL_UNSIGNED_BYTE, rgbaImage.data);
    *writeGLTextureTime = GetElapsedTime(t);
    LOGD("Write back to texture2D costs %f ms", *writeGLTextureTime);
  }
  // Visualize the results to image
  void VisualizeResults(std::vector<std::string> rec_text,
                        std::vector<float> rec_text_score, cv::Mat *rgbaImage,
                        double *visualizeResultsTime);
  // Visualize the status(performace data) to image
  void VisualizeStatus(double readGLFBOTime, double writeGLTextureTime,
                       double predictTime, std::vector<std::string> rec_text,
                       std::vector<float> rec_text_score,
                       double visualizeResultsTime, cv::Mat *rgbaImage);

  OcrRunResult RunOcrData(cv::Mat &bgrImage, const std::string &visualizedPath,
                          const std::string &variant);
  std::string RunOcr(cv::Mat &bgrImage, const std::string &visualizedPath,
                     double *predictTime);
  std::string BuildOcrJson(const std::vector<OcrRunResult> &runs,
                           int bestIndex);
  std::vector<std::pair<std::string, cv::Mat>>
  BuildDniPreprocessVariants(const cv::Mat &bgrImage);
  cv::Mat AutoCropDni(const cv::Mat &bgrImage);
  cv::Mat RectifyDni(const cv::Mat &bgrImage);
  cv::Mat EnhanceDni(const cv::Mat &bgrImage, bool binary);
  cv::Mat EnhanceDniFields(const cv::Mat &bgrImage);
  cv::Mat CropRelative(const cv::Mat &image, double x, double y, double width,
                       double height);
  int ScoreOcrRun(const OcrRunResult &run);

private:
  std::map<std::string, double> Config_;
  std::vector<std::string> charactor_dict_;
  std::shared_ptr<ClsPredictor> clsPredictor_;
  std::shared_ptr<DetPredictor> detPredictor_;
  std::shared_ptr<RecPredictor> recPredictor_;
};
