extends CharacterBody2D

const SPEED = 100
const ATTACK_RANGE = 25.0 
const KNOCKBACK_FORCE: float = 100.0 # Added from your reference

var target = null
var last_direction: Vector2 = Vector2.DOWN
var health: int = 20
var is_dead: bool = false
var attack_cooldown: float = 0.0 # Prevents the skeleton from attacking 60 times a second

# FIX 1: Properly declare the knockback variable here
var is_knocked_back: bool = false 

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var take_damage_sound: AudioStreamPlayer2D = $TakeDamage
@onready var health_bar: Node2D = $HealthBar


func _physics_process(delta: float) -> void:
	if is_dead or is_knocked_back:
		return
		
	# FIX 2: Add the sliding physics! If knocked back, slide and skip the AI
	if is_knocked_back:
		# Friction: Smoothly slow the skeleton down while sliding
		velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
		move_and_slide()
		return
		
	# Count down the skeleton's attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	if target:
		var direction = (target.position - position).normalized()
		last_direction = direction
		
		var distance = position.distance_to(target.position)
		
		if distance <= ATTACK_RANGE:
			velocity = Vector2.ZERO
			_play_directional_animation("killing")
			
			# Deal 10 damage to the player if the cooldown is finished
			if attack_cooldown <= 0.0:
				if target.has_method("take_damage"):
					target.take_damage(10)
				attack_cooldown = 1.0 # Wait 1 second before the next damage tick
		else:
			velocity = direction * SPEED
			_play_directional_animation("running")
	else:
		velocity = Vector2.ZERO
		_play_directional_animation("idle")

	move_and_slide()


func _play_directional_animation(action: String) -> void:
	if abs(last_direction.x) > abs(last_direction.y):
		animated_sprite_2d.play(action + "_right")
		animated_sprite_2d.flip_h = last_direction.x < 0
	else:
		# Reset flip_h to false for up and down animations
		animated_sprite_2d.flip_h = false 
		
		if last_direction.y > 0:
			animated_sprite_2d.play(action + "_down")
		else:
			animated_sprite_2d.play(action + "_up")


func _on_sight_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		target = body
		# Put the player in combat mode
		body.is_hostile = true
		body.hostile_timer = 10.0


func _on_sight_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		target = null


func take_damage(amount: int, attacker_position: Vector2) -> void:
	if is_dead:
		return
		
	health -= amount
	health_bar.update_health(health)
	if take_damage_sound:
		take_damage_sound.play()
		
	print("Skeleton health: ", health)
	
	if health <= 0:
		die()
		return 
		
	# Instantly stun the skeleton by resetting its attack cooldown
	attack_cooldown = 1.0 
	
	# --- KNOCKBACK TWEEN LOGIC ---
	is_knocked_back = true 
	
	var knockback_direction = (global_position - attacker_position).normalized()
	
	# Uses the KNOCKBACK_FORCE constant (e.g., 100) to determine how far it slides
	var target_position = position + knockback_direction * KNOCKBACK_FORCE
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Set to 0.3 seconds for a fast, snappy knockback instead of a slow glide
	tween.tween_property(self, "position", target_position, 0.3)
	
	# Wait for the fast slide to finish
	await tween.finished
	
	# Allow the skeleton to immediately resume chasing
	is_knocked_back = false

func die() -> void:
	is_dead = true
	is_knocked_back = false # Cancel any sliding
	velocity = Vector2.ZERO
	target = null
	
	# Turn off collision so it doesn't block the player
	$CollisionShape2D.set_deferred("disabled", true)
	$Sight/CollisionShape2D.set_deferred("disabled", true)
	
	# Play the death animation
	animated_sprite_2d.play("dead") 
	await animated_sprite_2d.animation_finished
	
	#queue_free() # Remove from scene
