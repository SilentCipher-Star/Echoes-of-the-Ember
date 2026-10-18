extends CharacterBody2D

const SPEED = 300.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var swing_weapon: AudioStreamPlayer2D = $SwingWeapon
@onready var hit_box: Area2D = $HitBox

var is_hostile : bool = false
var is_attacking : bool = false
var hostile_timer : float = 0.0 # Tracks the 10-second cooldown
var hitbox_offset: Vector2
var last_direction : Vector2 = Vector2.RIGHT

var health: int = 100
var is_dead: bool = false


func _ready() -> void:
	# initialization hitbox offset
	hitbox_offset = hit_box.position
	
	
func _physics_process(delta: float) -> void:
	# Stop doing physics and movement if the player is dead
	if is_dead:
		return
		
	# Tick down the timer if we are hostile but not currently swinging
	if is_hostile and not is_attacking:
		hostile_timer -= delta
		if hostile_timer <= 0.0:
			is_hostile = false # 10 seconds have passed, return to passive

	process_movement()
	move_and_slide()
	
	# Detect if the player's physical body bumps into the Skeleton
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If the thing we touched is the Skeleton, switch to combat mode
		if collider and collider.name.begins_with("Skeleton"):
			is_hostile = true
			hostile_timer = 10.0 # Reset cooldown so they stay in combat mode


func process_movement() -> void:
	if is_attacking:
		return
		
	if Input.is_action_just_pressed("ui_accept"):
		attack()
		return

	var direction := Input.get_vector("left", "right", "up", "down")
	velocity = direction * SPEED
	last_direction = direction
	update_hitbox_offset()
	play_animation(direction)


func play_animation(dir : Vector2) -> void:
	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		
	if dir != Vector2.ZERO:
		if is_hostile:
			animated_sprite_2d.play("runnning")
		else:
			animated_sprite_2d.play("passive_running")
	else:
		if is_hostile:
			animated_sprite_2d.play("idle")
		else:
			animated_sprite_2d.play("passive_idle")


func attack() -> void:
	is_attacking = true
	velocity = Vector2.ZERO 
	
	is_hostile = true 
	hostile_timer = 10.0 
	
	animated_sprite_2d.play("Hostile_Attack")
	swing_weapon.play()
	
	# DEAL DAMAGE INSTANTLY: Do not put 'await' before this loop
	var hit_something = hit_box.get_overlapping_bodies()
	for body in hit_something:
		if body != self and body.has_method("take_damage"):
			body.take_damage(5, global_position)
			
	# Wait for the animation to finish before letting the player walk again
	await animated_sprite_2d.animation_finished
	
	is_attacking = false

#---------------------------------------------------
#HITBOX
#---------------------------------------------------
func update_hitbox_offset() -> void:
	# Use abs() to ensure the base distance is always positive
	var dist = abs(hitbox_offset.x)
	var y = hitbox_offset.y
	
	match last_direction:
		Vector2.LEFT:
			hit_box.position = Vector2(-dist, y)
		Vector2.RIGHT:
			hit_box.position = Vector2(dist, y)
		Vector2.UP:
			# X is 0 to perfectly center it horizontally above the player
			hit_box.position = Vector2(0, -dist)
		Vector2.DOWN:
			# X is 0 to perfectly center it horizontally below the player
			hit_box.position = Vector2(0, dist)


			
			
#---------------------------------------------------
# HEALTH & DEATH
#---------------------------------------------------
func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	health -= amount
	print("Player health: ", health)
	
	if health <= 0:
		die()


func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	
	# Turn off collision so the skeleton stops attacking the dead body
	$CollisionShape2D.set_deferred("disabled", true)
	
	# If you have a player death animation, uncomment the next two lines:
	# animated_sprite_2d.play("died")
	# await animated_sprite_2d.animation_finished
	
	print("Player has died!")
	queue_free() # Removes the player from the game
