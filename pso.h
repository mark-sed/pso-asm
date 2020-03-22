#ifndef _PSO_H_
#define _PSO_H_

#include <time.h>
#include <stdlib.h>
#include <stdbool.h>

#include <float.h>

#define COEFF_W  0.50  //< Inertia coefficient (should be in range of <0.4, 0.9>)
#define COEFF_CP 2.05  //< Cognitive coefficient (should be a little bit above 2)
#define COEFF_CG 2.05  //< Social coefficient (should have same or similar value as cognitive coefficient)

/**
 * Return type for statical PSO
 */
typedef struct {
    double x;  //< X coordinate
    double y;  //< Y coordinate
} TPSOxy;

#define PSO3DIM_STATIC_PARTICLES 20

typedef struct {
	double velocity1[PSO3DIM_STATIC_PARTICLES];
	double velocity2[PSO3DIM_STATIC_PARTICLES];
	double position1[PSO3DIM_STATIC_PARTICLES];
	double position2[PSO3DIM_STATIC_PARTICLES];
	double best_pos1[PSO3DIM_STATIC_PARTICLES];
	double best_pos2[PSO3DIM_STATIC_PARTICLES];
	double best_val[PSO3DIM_STATIC_PARTICLES];
} TSwarm;

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
    extern unsigned long seed;
    seed = time(NULL);
    srand(time(NULL));
}

double random_double(double min, double max){
	//static int i = 1;
	//printf("%d MIN: %f, MAX: %f\n", i++, min, max);
	double r = min + (rand() / (RAND_MAX / (max-min)));
	
	//printf("%d. %f \n", i++, r);
	return r;
	//return min + (rand() / (RAND_MAX / (max-min)));
}

double rnd_dbl();


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

TPSOxy pso3dim_static_opt(func3dim function, double bounds[2][2], fit_func fitness, unsigned long max_iter){
    // Create array of particles (swarm)
    TSwarm swarm;
    // Initialize the particles
    for(unsigned int i = 0; i < PSO3DIM_STATIC_PARTICLES; i++){
        // Set values for every dimension
	    // Random velocity from -1 to 1
	    swarm.velocity1[i] = random_double(-1, 1);
	    swarm.velocity2[i] = random_double(-1, 1);
	    // Random position from minimal possible to maximal and set best position to current
	    swarm.best_pos1[i] = swarm.position1[i] = random_double(bounds[0][0], bounds[0][1]);
	    swarm.best_pos2[i] = swarm.position2[i] = random_double(bounds[1][0], bounds[1][1]);

    }

    double best_pos[2];
    double best_value = DBL_MAX;

    for(unsigned long i = 0; i < max_iter; i++){
        for(unsigned int a = 0; a < PSO3DIM_STATIC_PARTICLES; a++){
            // Evaluate current position of the current particle
            double value = function(swarm.position1[a], swarm.position2[a]);
            // Check if this is new personal best value
            if(fitness(value, swarm.best_val[a]) || i == 0){
                // Save the personal best position and value
                swarm.best_val[a] = value;
                swarm.best_pos1[a] = swarm.position1[a];
                swarm.best_pos2[a] = swarm.position2[a];
                // Now check if the value is better than global best value
                // This can be inside this if statement because any global best
                //   has to have better or same fitness function value than
                //   any personal best
                if(fitness(value, best_value) || best_value == DBL_MAX){
                    best_value = value;
                    best_pos[0] = swarm.position1[a];
                    best_pos[1] = swarm.position2[a];
                }
            }
        }
        // Updating the velocity and position of particles
        for(unsigned int a = 0; a < PSO3DIM_STATIC_PARTICLES; a++){
            // Random coefficient pre-multiplied by cognitive/social coefficient
		    double rp = random_double(0, 1) * COEFF_CP;
		    double rg = random_double(0, 1) * COEFF_CG;

		    // Calculate new velocity for both dimensions
		    // Calculating with non-dependent values first to not slow down processing pipeline
		    // Differences are pre-calculated to avoid calculating them twice
		    double pos_diff0 = best_pos[0] - swarm.position1[a];
		    double pos_diff1 = best_pos[1] - swarm.position2[a];
		    swarm.velocity1[a] = COEFF_W * swarm.velocity1[a] + rp * pos_diff0 + rg * pos_diff0;
		    swarm.velocity2[a] = COEFF_W * swarm.velocity2[a] + rp * pos_diff1 + rg * pos_diff1;

		    // Calculate new position
		    // Adjust if new position is out of bounds
		    swarm.position1[a] += swarm.velocity1[a];
		    swarm.position2[a] += swarm.velocity2[a];

		    // Check bounds for 1st dimension
		    if(swarm.position1[a] < bounds[0][0]){
		        swarm.position1[a] = bounds[0][0];
		    }
		    else if(swarm.position1[a] > bounds[0][1]){
		        swarm.position1[a] = bounds[0][1];
		    }

		    // Check bounds for 2nd dimension
		    if(swarm.position2[a] < bounds[1][0]){
		        swarm.position2[a] = bounds[1][0];
		    }
		    else if(swarm.position2[a] > bounds[1][1]){
		        swarm.position2[a] = bounds[1][1];
		    }
        }
    }

    return (TPSOxy){best_pos[0], best_pos[1]};
}

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
