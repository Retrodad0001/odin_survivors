package survivors

MAX_ENTITIES: int : 1000

EntityId :: distinct int

Position :: struct {
	x, y: f32,
}

Entity :: struct {
	id:       EntityId,
	position: Position,
}

EntityManager :: struct {
	entities: #soa[MAX_ENTITIES]Entity,
}

entity_create_entity_manager :: proc() -> EntityManager {
	manager: EntityManager
	entity_id_counter := 0
	for _ in manager.entities {
		manager.entities[entity_id_counter].id = EntityId(entity_id_counter)
		manager.entities[entity_id_counter].position = Position{0.0, 0.0}
		entity_id_counter += 1
	}
	return manager
}
