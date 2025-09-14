import { Injectable } from '@nestjs/common';
import axios from 'axios';
import * as FormData from 'form-data';
import * as fs from 'fs';
import * as path from 'path';
import { Detection } from './dto/Detection.dto';

interface FileLike {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
}

interface FastApiResponse {
  ok: boolean;
  photo?: string; // ожидаем base64 строки (например "data:image/jpeg;base64,...")
  detections?: Detection[];
}

@Injectable()
export class CarVerifService {
  private readonly FASTAPI_URL = 'http://car-ml:8000/check-car';
  private readonly BATCH_SIZE = 30;

  async verifyCar(
    files: FileLike[],
  ): Promise<{ ok: boolean; photo: string; detections: Detection[] }> {
    // true по умолчанию — пока не найдём ни одной детекции
    let overallOk = true;
    let overallPhoto = 'null';
    const overallDetections: Detection[] = [];

    for (let i = 0; i < files.length; i += this.BATCH_SIZE) {
      const batch = files.slice(i, i + this.BATCH_SIZE);

      for (const file of batch) {
        if (!file?.buffer) continue;

        const formData = new FormData();
        formData.append('file', file.buffer, {
          filename: file.originalname,
          contentType: file.mimetype,
        });

        try {
          const response = await axios.post<FastApiResponse>(
            this.FASTAPI_URL,
            formData,
            { headers: formData.getHeaders() },
          );

          const { photo, detections } = response.data;

          // ✅ Если есть хотя бы одна детекция — весь результат = false
          if (detections && detections.length > 0) {
            overallOk = false;
            overallDetections.push(...detections);
          }

          if (photo) {
            overallPhoto = photo;

            // сохраняем изображение
            const base64Data = photo.includes(',')
              ? photo.split(',')[1]
              : photo;

            const buffer = Buffer.from(base64Data, 'base64');
            const publicDir = path.join(__dirname, '..', '..', 'public');
            fs.mkdirSync(publicDir, { recursive: true });

            const outPath = path.join(
              publicDir,
              `car_${Date.now()}_${file.originalname}`,
            );
            fs.writeFileSync(outPath, buffer);
          }
        } catch (e) {
          console.log(e);
          // при ошибке считаем что проверка не пройдена
          overallOk = false;
        }
      }
    }

    return {
      ok: overallOk,
      photo: overallPhoto,
      detections: overallDetections,
    };
  }
}
