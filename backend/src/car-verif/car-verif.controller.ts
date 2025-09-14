import {
  Controller,
  Post,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { AnyFilesInterceptor } from '@nestjs/platform-express';
import { CarVerifService } from './car-verif.service';

@Controller('car-verif')
export class CarVerifController {
  constructor(private readonly carVerifService: CarVerifService) {}

  @Post()
  @UseInterceptors(AnyFilesInterceptor())
  async verify(@UploadedFiles() files: any[]) {
    console.log(files);
    return this.carVerifService.verifyCar(files);
  }
}
