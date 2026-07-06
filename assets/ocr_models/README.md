Coloca aqui los modelos OCR offline antes de compilar una version con OCR real.

Modelos Android nativos activos:
- ch_PP-OCRv2_det_slim_opt.nb
- ch_PP-OCRv2_rec_slim_opt.nb
- ch_ppocr_mobile_v2.0_cls_slim_opt.nb, si se activa clasificacion de orientacion

Lectura principal de texto:
- ML Kit Text Recognition Latin bundled, local en el dispositivo.
- Paddle Lite queda como fallback y para visualizacion de cajas OCR.

La app no usa internet. Los modelos deben viajar empaquetados como assets locales.
