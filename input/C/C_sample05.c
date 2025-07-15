#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 24
#define MAX_ENTITIES 100
#define MAX_PARTICLES 500
#define GRAVITY 0.5f
#define FRICTION 0.95f


typedef struct {
    float x, y;
} Vector2D;


typedef enum {
    ENTITY_PLAYER,
    ENTITY_ENEMY,
    ENTITY_PROJECTILE,
    ENTITY_POWERUP,
    ENTITY_PLATFORM
} EntityType;


typedef struct {
    int id;
    EntityType type;
    Vector2D position;
    Vector2D velocity;
    Vector2D size;
    char symbol;
    int health;
    int active;
    float mass;
    int solid;
} Entity;


typedef struct {
    Vector2D position;
    Vector2D velocity;
    char symbol;
    int lifetime;
    int active;
} Particle;


typedef struct {
    Entity entities[MAX_ENTITIES];
    Particle particles[MAX_PARTICLES];
    int entity_count;
    int particle_count;
    int score;
    int level;
    int game_over;
    int paused;
    char screen[SCREEN_HEIGHT][SCREEN_WIDTH + 1];
    float delta_time;
    clock_t last_time;
} GameState;


GameState* init_game(void) {
    GameState* game = malloc(sizeof(GameState));
    if (!game) return NULL;
    
    memset(game, 0, sizeof(GameState));
    game->entity_count = 0;
    game->particle_count = 0;
    game->score = 0;
    game->level = 1;
    game->game_over = 0;
    game->paused = 0;
    game->last_time = clock();
    
    printf("Game engine initialized\n");
    return game;
}


Vector2D vector_add(Vector2D a, Vector2D b) {
    Vector2D result = {a.x + b.x, a.y + b.y};
    return result;
}

Vector2D vector_multiply(Vector2D v, float scalar) {
    Vector2D result = {v.x * scalar, v.y * scalar};
    return result;
}

float vector_magnitude(Vector2D v) {
    return sqrtf(v.x * v.x + v.y * v.y);
}

Vector2D vector_normalize(Vector2D v) {
    float mag = vector_magnitude(v);
    if (mag > 0) {
        Vector2D result = {v.x / mag, v.y / mag};
        return result;
    }
    Vector2D zero = {0, 0};
    return zero;
}


int create_entity(GameState* game, EntityType type, float x, float y, char symbol) {
    if (game->entity_count >= MAX_ENTITIES) return -1;
    
    Entity* entity = &game->entities[game->entity_count];
    entity->id = game->entity_count;
    entity->type = type;
    entity->position.x = x;
    entity->position.y = y;
    entity->velocity.x = 0;
    entity->velocity.y = 0;
    entity->size.x = 1;
    entity->size.y = 1;
    entity->symbol = symbol;
    entity->health = 100;
    entity->active = 1;
    entity->mass = 1.0f;
    entity->solid = 1;
    
    
    switch (type) {
        case ENTITY_PLAYER:
            entity->health = 100;
            entity->mass = 2.0f;
            break;
        case ENTITY_ENEMY:
            entity->health = 50;
            entity->velocity.x = (rand() % 3 - 1) * 0.5f;
            break;
        case ENTITY_PROJECTILE:
            entity->health = 1;
            entity->mass = 0.1f;
            entity->solid = 0;
            break;
        case ENTITY_POWERUP:
            entity->solid = 0;
            break;
        case ENTITY_PLATFORM:
            entity->health = 1000;
            entity->mass = 100.0f;
            entity->velocity.x = 0;
            entity->velocity.y = 0;
            break;
    }
    
    return game->entity_count++;
}


void create_particle(GameState* game, float x, float y, float vx, float vy, char symbol) {
    if (game->particle_count >= MAX_PARTICLES) return;
    
    Particle* particle = &game->particles[game->particle_count];
    particle->position.x = x;
    particle->position.y = y;
    particle->velocity.x = vx;
    particle->velocity.y = vy;
    particle->symbol = symbol;
    particle->lifetime = 20 + rand() % 30;
    particle->active = 1;
    
    game->particle_count++;
}


int check_collision(Entity* a, Entity* b) {
    if (!a->active || !b->active) return 0;
    
    float left_a = a->position.x;
    float right_a = a->position.x + a->size.x;
    float top_a = a->position.y;
    float bottom_a = a->position.y + a->size.y;
    
    float left_b = b->position.x;
    float right_b = b->position.x + b->size.x;
    float top_b = b->position.y;
    float bottom_b = b->position.y + b->size.y;
    
    return !(left_a >= right_b || right_a <= left_b || top_a >= bottom_b || bottom_a <= top_b);
}


void handle_collision(Entity* a, Entity* b) {
    if (!a->solid && !b->solid) return;
    
    
    Vector2D relative_velocity = {a->velocity.x - b->velocity.x, a->velocity.y - b->velocity.y};
    float speed = vector_magnitude(relative_velocity);
    
    if (speed > 0.1f) {
        Vector2D normal = vector_normalize(relative_velocity);
        
        
        float overlap = 0.5f;
        a->position = vector_add(a->position, vector_multiply(normal, overlap));
        b->position = vector_add(b->position, vector_multiply(normal, -overlap));
        
        
        float impulse = 2 * speed / (a->mass + b->mass);
        a->velocity = vector_add(a->velocity, vector_multiply(normal, -impulse * b->mass));
        b->velocity = vector_add(b->velocity, vector_multiply(normal, impulse * a->mass));
    }
}


void update_entity(Entity* entity, float delta_time) {
    if (!entity->active) return;
    
    
    if (entity->type != ENTITY_PLATFORM) {
        entity->velocity.y += GRAVITY * delta_time;
    }
    
    
    entity->velocity = vector_multiply(entity->velocity, FRICTION);
    
    
    entity->position = vector_add(entity->position, vector_multiply(entity->velocity, delta_time));
    
    
    if (entity->position.x < 0) {
        entity->position.x = 0;
        entity->velocity.x = -entity->velocity.x * 0.5f;
    }
    if (entity->position.x >= SCREEN_WIDTH - entity->size.x) {
        entity->position.x = SCREEN_WIDTH - entity->size.x;
        entity->velocity.x = -entity->velocity.x * 0.5f;
    }
    if (entity->position.y >= SCREEN_HEIGHT - entity->size.y) {
        entity->position.y = SCREEN_HEIGHT - entity->size.y;
        entity->velocity.y = 0;
    }
    
    
    if (entity->position.y > SCREEN_HEIGHT + 5) {
        entity->active = 0;
    }
}


void update_particles(GameState* game, float delta_time) {
    for (int i = 0; i < game->particle_count; i++) {
        Particle* particle = &game->particles[i];
        if (!particle->active) continue;
        
        particle->position = vector_add(particle->position, 
                                      vector_multiply(particle->velocity, delta_time));
        particle->velocity.y += GRAVITY * delta_time * 0.1f;
        particle->lifetime--;
        
        if (particle->lifetime <= 0 || 
            particle->position.x < 0 || particle->position.x >= SCREEN_WIDTH ||
            particle->position.y < 0 || particle->position.y >= SCREEN_HEIGHT) {
            particle->active = 0;
        }
    }
}


void clear_screen(GameState* game) {
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        for (int x = 0; x < SCREEN_WIDTH; x++) {
            game->screen[y][x] = ' ';
        }
        game->screen[y][SCREEN_WIDTH] = '\0';
    }
}


void render_entity(GameState* game, Entity* entity) {
    if (!entity->active) return;
    
    int x = (int)entity->position.x;
    int y = (int)entity->position.y;
    
    if (x >= 0 && x < SCREEN_WIDTH && y >= 0 && y < SCREEN_HEIGHT) {
        game->screen[y][x] = entity->symbol;
    }
}


void render_particle(GameState* game, Particle* particle) {
    if (!particle->active) return;
    
    int x = (int)particle->position.x;
    int y = (int)particle->position.y;
    
    if (x >= 0 && x < SCREEN_WIDTH && y >= 0 && y < SCREEN_HEIGHT) {
        game->screen[y][x] = particle->symbol;
    }
}


void render_frame(GameState* game) {
    clear_screen(game);
    
    
    for (int i = 0; i < game->entity_count; i++) {
        render_entity(game, &game->entities[i]);
    }
    
    
    for (int i = 0; i < game->particle_count; i++) {
        render_particle(game, &game->particles[i]);
    }
    
    
    printf("\033[2J\033[H"); 
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        printf("%s\n", game->screen[y]);
    }
    
    
    printf("Score: %d | Level: %d | Entities: %d | Particles: %d\n", 
           game->score, game->level, game->entity_count, game->particle_count);
    if (game->paused) printf("PAUSED - Press 'p' to continue\n");
    if (game->game_over) printf("GAME OVER - Press 'r' to restart\n");
}


void spawn_enemy(GameState* game) {
    if (rand() % 100 < 5) { 
        float x = rand() % (SCREEN_WIDTH - 2);
        create_entity(game, ENTITY_ENEMY, x, 0, 'E');
        
        
        for (int i = 0; i < 5; i++) {
            float vx = (rand() % 100 - 50) / 50.0f;
            float vy = (rand() % 100 - 50) / 50.0f;
            create_particle(game, x, 0, vx, vy, '*');
        }
    }
}


void update_game(GameState* game) {
    if (game->paused || game->game_over) return;
    
    
    clock_t current_time = clock();
    game->delta_time = (float)(current_time - game->last_time) / CLOCKS_PER_SEC;
    game->last_time = current_time;
    
    
    for (int i = 0; i < game->entity_count; i++) {
        update_entity(&game->entities[i], game->delta_time);
    }
    
    
    for (int i = 0; i < game->entity_count; i++) {
        for (int j = i + 1; j < game->entity_count; j++) {
            if (check_collision(&game->entities[i], &game->entities[j])) {
                handle_collision(&game->entities[i], &game->entities[j]);
                
                
                Entity* a = &game->entities[i];
                Entity* b = &game->entities[j];
                
                if ((a->type == ENTITY_PLAYER && b->type == ENTITY_ENEMY) ||
                    (a->type == ENTITY_ENEMY && b->type == ENTITY_PLAYER)) {
                    game->score += 10;
                    
                    
                    for (int k = 0; k < 10; k++) {
                        float vx = (rand() % 200 - 100) / 50.0f;
                        float vy = (rand() % 200 - 100) / 50.0f;
                        create_particle(game, a->position.x, a->position.y, vx, vy, '#');
                    }
                }
            }
        }
    }
    
    update_particles(game, game->delta_time);
    spawn_enemy(game);
    
    
    int active_entities = 0;
    for (int i = 0; i < game->entity_count; i++) {
        if (game->entities[i].active) {
            if (i != active_entities) {
                game->entities[active_entities] = game->entities[i];
            }
            active_entities++;
        }
    }
    game->entity_count = active_entities;
    
    
    int active_particles = 0;
    for (int i = 0; i < game->particle_count; i++) {
        if (game->particles[i].active) {
            if (i != active_particles) {
                game->particles[active_particles] = game->particles[i];
            }
            active_particles++;
        }
    }
    game->particle_count = active_particles;
}


void setup_demo_level(GameState* game) {
    
    create_entity(game, ENTITY_PLAYER, SCREEN_WIDTH / 2, SCREEN_HEIGHT - 5, 'P');
    
    
    for (int i = 0; i < SCREEN_WIDTH; i += 10) {
        create_entity(game, ENTITY_PLATFORM, i, SCREEN_HEIGHT - 1, '=');
        create_entity(game, ENTITY_PLATFORM, i, SCREEN_HEIGHT / 2, '-');
    }
    
    
    for (int i = 0; i < 3; i++) {
        float x = rand() % (SCREEN_WIDTH - 2);
        create_entity(game, ENTITY_ENEMY, x, rand() % 10, 'E');
    }
    
    printf("Demo level initialized\n");
}


void run_game(GameState* game) {
    setup_demo_level(game);
    
    printf("Game started! This is a simple demonstration.\n");
    printf("Watch the entities interact with physics and collision detection.\n");
    printf("Press Ctrl+C to exit.\n");
    
    while (!game->game_over) {
        update_game(game);
        render_frame(game);
        
        
        usleep(50000); 
        
        
        if (game->score > 100) {
            printf("\nDemo completed successfully!\n");
            break;
        }
    }
}


void free_game(GameState* game) {
    if (game) {
        free(game);
        printf("Game resources freed\n");
    }
}

int main(void) {
    printf("2D Game Engine Demo\n");
    printf("===================\n");
    
    srand(time(NULL));
    
    GameState* game = init_game();
    if (!game) {
        printf("Failed to initialize game\n");
        return EXIT_FAILURE;
    }
    
    run_game(game);
    free_game(game);
    
    printf("Game engine demo completed\n");
    return EXIT_SUCCESS;
} 