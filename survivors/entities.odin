package survivors

@(private)
MAX_ENTITIES: int : 1000

@(private)
EntityId :: distinct int

@(private)
Entity :: struct {
	id:       EntityId,
	position: [2]f32, // x, y position
}

@(private)
EntityManager :: struct {
	entities: #soa[MAX_ENTITIES]Entity,
}

@(private)
entity_create_entity_manager :: proc() -> EntityManager {
	manager: EntityManager
	entity_id_counter := 0
	for _ in manager.entities {
		manager.entities[entity_id_counter].id = EntityId(entity_id_counter)
		manager.entities[entity_id_counter].position = [2]f32{0.0, 0.0}
		entity_id_counter += 1
	}
	return manager
}
