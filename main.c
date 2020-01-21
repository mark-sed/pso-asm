#include "pso.h"
#include <math.h>
#include <stdbool.h>
#include <float.h>
#include <stdio.h>

#ifndef M_PI
// PI (Taken from boost library)
#define M_PI (double)(3.14159265358979323846264338327950288419716939937510582097494459230781640628620899862803482534211706798214808651e+00)
#endif

#ifndef M_E
// Euler's constant (taken from boost library)
#define M_E (double)(2.71828182845904523536028747135266249775724709369995957496696762772407663035354759457138217852516642742746639193e+00)
#endif

/*
typedef struct {
    double velocity[2];  //< Velocity for each dimension
    double position[2];  //< Position in each dimension
    double best_pos[2];  //< Best position
    double best_val;     //< Value of the best position
    double a;			 //< added padding
} TParticle3Dim;

extern TParticle3Dim swarm[];*/


double ackleys_function(double x, double y){
    return -20 * pow(M_E, -0.2*sqrt(0.5*(x*x + y*y))) - pow(M_E, 0.5*(cos(2*M_PI*x)+cos(2*M_PI*y))) + M_E + 20;
}

double func2(double x, double y){
  return ((1.0-x)*(1.0-x)) + 100*((y - x*x)*(y - x*x));
}


int main(int argc, char *argv[]){
   pso_init();
   double bounds[][2] = {{-50.0, 50.0}, {-50., 50.}};

   TPSOxy res = pso3dim_static(ackleys_function, bounds, fitness_less_than, 50);

   printf("[%.*e, %.*e]\n", DECIMAL_DIG, res.x, DECIMAL_DIG, res.y);

   return 0;
}
