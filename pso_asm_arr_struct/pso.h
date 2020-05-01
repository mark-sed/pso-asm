/**
 * @file pso.h
 * @author Marek Sedláček
 * @date April 2020
 * 
 * @brief Header file for PSO module
 *
 * This header file contains functions and type declarations
 * for Particle Swarm Optimization (PSO) module.
 * PSO module is able optimize functions using PSO algorithm.
 *
 * This code was made for my bachelor's thesis at
 * Brno University of Technology
 */

#ifndef _PSO_H_
#define _PSO_H_

#include <time.h>
#include <stdlib.h>
#include <stdbool.h>

/**
 * Return type for static PSO
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

/**
 * Generates a random double in range
 * RAND_MAX is taken from https://en.cppreference.com/w/c/numeric/random/RAND_MAX
 */
double random_double(double min, double max){
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

/**
 * Fitness function looking for minimum
 * @param a first value to compare
 * @param b second value to compare
 * @return true if a < b, else false
 */
bool fitness_less_than(double a, double b);

/**
 * Fitness function looking for maximum
 * @param a first value to compare
 * @param b second value to compare
 * @return true if a > b, else false
 */
bool fitness_greater_than(double a, double b);

#endif//_PSO_H_
