from fastapi import FastAPI, UploadFile, File, HTTPException
from inference import get_model
import cv2
import numpy as np
import base64

app = FastAPI()

car_model = get_model(model_id="car-detect-7gxcl/1")
scratch_model = get_model(model_id="car-scratch-xgxzs/1")

CONFIDENCE_THRESHOLD = 0.9


@app.post("/check-car")
async def check_car(file: UploadFile = File(...)):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Нужен файл изображения")

    img_bytes = await file.read()
    np_arr = np.frombuffer(img_bytes, np.uint8)
    image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    car_results = car_model.infer(image)[0]
    car_predictions = car_results.predictions

    car_detected = any(
        p.confidence >= CONFIDENCE_THRESHOLD for p in car_predictions)

    annotated_image = image.copy()
    if car_detected or not car_detected:
        for p in car_predictions:
            if p.confidence >= CONFIDENCE_THRESHOLD:
                x, y = int(p.x), int(p.y)
                w, h = int(p.width), int(p.height)
                cv2.rectangle(annotated_image, (x, y),
                              (x + w, y + h), (0, 255, 0), 2)
                cv2.putText(
                    annotated_image,
                    f'{p.class_name} {p.confidence:.2f}',
                    (x, y - 10),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.9,
                    (0, 255, 0),
                    2
                )

    detections_info = []
    if car_detected:
        scratch_results = scratch_model.infer(image)[0]
        scratch_predictions = scratch_results.predictions

        detections_info = [
            {"class": p.class_name, "confidence": p.confidence}
            for p in scratch_predictions
        ]

        for p in scratch_predictions:
            x, y = int(p.x), int(p.y)
            w, h = int(p.width), int(p.height)
            cv2.rectangle(annotated_image, (x, y),
                          (x + w, y + h), (0, 0, 255), 2)
            cv2.putText(
                annotated_image,
                f'{p.class_name} {p.confidence:.2f}',
                (x, y - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.9,
                (0, 0, 255),
                2
            )

    ok = car_detected and len(detections_info) == 0

    _, buffer = cv2.imencode(".jpg", annotated_image)
    img_base64 = base64.b64encode(buffer).decode("utf-8")

    return {
        "ok": ok,
        "photo": img_base64,
        "detections": detections_info,
        "car_detected": car_detected
    }
