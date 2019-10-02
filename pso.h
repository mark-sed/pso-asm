#ifndef _PSO_H_
#define _PSO_H_

#include <time.h>
#include <stdlib.h>
#include <stdbool.h>

/**
 * Return type for statical PSO
 */
typedef struct {
    double x;  //< X coordinate
    double y;  //< Y coordinate
} TPSOxy;

/**
 * Fitness function
 * Parameters are 2 values to be compared
 * @return true if 1st argument is better than 2nd argument
 */
typedef bool (* fit_func)(double, double);

/**
 * 3 dimensional function
 * Parameters are x and y value
 * @return function value at passed in coordinates
 */
typedef double (* func3dim)(double, double);

/**
 * Initializer function for PSO module
 * @warning This function should be called only once before any other PSO function is called
 * @note This function calls srand function
 */
void pso_init(){
    // Initializing pseudo-random generator
    srand(time(NULL));
}

double random_double(double min, double max){
	/*static int i = 1;
	printf("%d MIN: %f, MAX: %f\n", i++, min, max);
	double r = min + (rand() / (RAND_MAX / (max-min)));
	printf("%d. %f \n", i++, r); */
	return min + (rand() / (RAND_MAX / (max-min)));
}


/**
 * Particle swarm optimization algorithm for 3 dimensional functions that does not use dynamical allocation
 * @param function Function in which is optimization done
 * @param bounds Bounds of the function in which will be the function optimized.
 *               this should be 2 arrays of 2 values where the 1st one is
 *               the minimum and second one is the maximum. E.g.: for `x in <0, 5> &
 *               y in <-10, 10>` the bounds should be `{{0.0, 5.0}, {-10.0, 10.0}}`.
 * @param fitness Fitness functions that determinates if passed in value is better
 *                than other passed in value
 * @param max_iter The amount of iterations that should be done.
 *                 More results in better precision but longer calculation.
 * @return Struct with 2 doubles - the best found x and y coordinates.
 * @note The amount of particles is determinated by the value of `PSO3DIM_STATIC_PARTICLES` macro
 */
TPSOxy pso3dim_static(func3dim function, double bounds[2][2], fit_func fitness, unsigned long max_iter);

#endif//_PSO_H_
