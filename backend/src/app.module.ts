import { Module } from '@nestjs/common';
import { CarVerifModule } from './car-verif/car-verif.module';

@Module({
  imports: [CarVerifModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
