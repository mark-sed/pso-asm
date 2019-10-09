#include "pso.h"
#include <math.h>
#include <stdbool.h>

// Remove?
#include <float.h>
#include <stdio.h>
#include <stdlib.h>

#ifndef M_PI
// PI (Taken from boost library)
#define M_PI (double)(3.14159265358979323846264338327950288419716939937510582097494459230781640628620899862803482534211706798214808651e+00)
#endif

#ifndef M_E
// Euler's constant (taken from boost library)
#define M_E (double)(2.71828182845904523536028747135266249775724709369995957496696762772407663035354759457138217852516642742746639193e+00)
#endif

bool less_than(double a, double b){
    return a < b;
}

double ackleys_function(double x, double y){
    return -20 * pow(M_E, -0.2*sqrt(0.5*(x*x + y*y))) - pow(M_E, 0.5*(cos(2*M_PI*x)+cos(2*M_PI*y))) + M_E + 20;
}

/*typedef struct {
    double velocity[2];  //< Velocity for each dimension
    double position[2];  //< Position in each dimension
    double best_pos[2];  //< Best position
    double best_val;     //< Value of the best position
    double a;			 //< added padding
} TParticle3Dim;

extern TParticle3Dim swarm[];*/


int main(int argc, char *argv[]){
   pso_init();
   double bounds[][2] = {{-50.0, 50.0}, {-50., 50.}};

   TPSOxy res = pso3dim_static(ackleys_function, bounds, less_than, 1000000);

   printf("[%.*e, %.*e]\n", DECIMAL_DIG, res.x, DECIMAL_DIG, res.y);

/*
  for(int i = 0; i < 20; i++){
   	TParticle3Dim p = swarm[i];
   	printf("%d. %f %f - %f %f (%f, %f)\n", i, p.velocity[0], p.velocity[1], p.position[0], p.position[1], p.best_pos[0], p.best_pos[1]);
   }

   return 0;*/
}
