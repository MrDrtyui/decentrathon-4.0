import { Module } from '@nestjs/common';
import { CarVerifService } from './car-verif.service';
import { CarVerifController } from './car-verif.controller';

@Module({
  controllers: [CarVerifController],
  providers: [CarVerifService],
})
export class CarVerifModule {}
